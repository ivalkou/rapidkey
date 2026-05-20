#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT"

# shellcheck source=lib/version.sh
source "$SCRIPT_DIR/lib/version.sh"

GITHUB_REPO="ivalkou/rapidkey"
HOMEBREW_TAP_DIR="$(cd "$ROOT/.." && pwd)/homebrew-tap"
PBXPROJ="$ROOT/$PBXPROJ_RELATIVE"

VERSION=""
BUMP_KIND=""
NOTES=""
DRY_RUN=0
ASSUME_YES=0
NO_PIN=0
SKIP_PUSH=0
ALLOW_DIRTY=0

usage() {
    cat <<EOF
Usage: $(basename "$0") --version X.Y.Z | --bump patch|minor|major [options]

Publish a RapidKey release: bump Xcode versions, build, GitHub Release, Homebrew tap.

Options:
  --version X.Y.Z     Explicit marketing version
  --bump KIND         Bump from current MARKETING_VERSION (patch|minor|major)
  --notes TEXT        GitHub release notes (default: short template)
  --dry-run           Print steps only; do not modify files or remotes
  --yes               Skip confirmation prompt
  --no-pin            Do not run pin.sh in homebrew-tap
  --skip-push         Commit locally but do not push git/gh/tap
  --allow-dirty       Allow uncommitted changes besides version bump
  -h, --help          Show this help

Examples:
  $(basename "$0") --bump patch --yes
  $(basename "$0") --version 0.2.0 --notes "Fix palette focus"
EOF
}

while test $# -gt 0; do
    case $1 in
        --version) VERSION="$2"; shift 2;;
        --bump) BUMP_KIND="$2"; shift 2;;
        --notes) NOTES="$2"; shift 2;;
        --dry-run) DRY_RUN=1; shift;;
        --yes) ASSUME_YES=1; shift;;
        --no-pin) NO_PIN=1; shift;;
        --skip-push) SKIP_PUSH=1; shift;;
        --allow-dirty) ALLOW_DIRTY=1; shift;;
        -h|--help) usage; exit 0;;
        *) echo "Unknown option: $1" >&2; usage >&2; exit 1;;
    esac
done

if test -z "$VERSION" && test -z "$BUMP_KIND"; then
    echo "Specify --version or --bump" >&2
    usage >&2
    exit 1
fi
if test -n "$VERSION" && test -n "$BUMP_KIND"; then
    echo "Use only one of --version or --bump" >&2
    exit 1
fi

run() {
    if test "$DRY_RUN" -eq 1; then
        echo "[dry-run] $*"
    else
        "$@"
    fi
}

require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Missing required command: $1" >&2
        exit 1
    fi
}

preflight() {
    require_command git
    require_command gh
    require_command xcodebuild
    require_command sed

    if ! test -f "$PBXPROJ"; then
        echo "Missing $PBXPROJ" >&2
        exit 1
    fi
    if ! test -d "$HOMEBREW_TAP_DIR/.git"; then
        echo "homebrew-tap not found at $HOMEBREW_TAP_DIR" >&2
        exit 1
    fi

    if test "$ALLOW_DIRTY" -eq 0; then
        if ! git diff --quiet || ! git diff --cached --quiet; then
            echo "Working tree has uncommitted changes. Commit/stash or pass --allow-dirty." >&2
            git status --short >&2
            exit 1
        fi
    fi

    if test "$DRY_RUN" -eq 1; then
        return 0
    fi

    if git rev-parse "v$VERSION" >/dev/null 2>&1; then
        echo "Tag v$VERSION already exists" >&2
        exit 1
    fi
    if gh release view "v$VERSION" --repo "$GITHUB_REPO" >/dev/null 2>&1; then
        echo "GitHub release v$VERSION already exists" >&2
        exit 1
    fi
}

current_marketing="$(read_marketing_version "$PBXPROJ")"
current_build="$(read_build_number "$PBXPROJ")"

if test -n "$BUMP_KIND"; then
    VERSION="$(bump_semver "$current_marketing" "$BUMP_KIND")"
fi
validate_semver "$VERSION" || exit 1

new_build=$((current_build + 1))

if test -z "$NOTES"; then
    NOTES="$(cat <<EOF
RapidKey v$VERSION

Install or upgrade via Homebrew:

\`\`\`bash
brew update && brew upgrade --cask ivalkou/tap/rapidkey
\`\`\`
EOF
)"
fi

echo "Current: MARKETING_VERSION=$current_marketing, CURRENT_PROJECT_VERSION=$current_build"
echo "Release: MARKETING_VERSION=$VERSION, CURRENT_PROJECT_VERSION=$new_build"
echo "homebrew-tap: $HOMEBREW_TAP_DIR"

preflight

if test "$ASSUME_YES" -eq 0 && test "$DRY_RUN" -eq 0; then
    echo
    read -r -p "Continue with release v$VERSION? [y/N] " reply
    case "$reply" in
        y|Y|yes|YES) ;;
        *) echo "Aborted."; exit 1;;
    esac
fi

echo "Updating Xcode project versions..."
if test "$DRY_RUN" -eq 1; then
    echo "[dry-run] set_xcode_versions $PBXPROJ $VERSION $new_build"
else
    set_xcode_versions "$PBXPROJ" "$VERSION" "$new_build"
fi

echo "Building release..."
run "$SCRIPT_DIR/build-release.sh" --build-version "$VERSION"

ZIP_PATH="$ROOT/.release/RapidKey-v$VERSION.zip"
CASK_PATH="$ROOT/.release/rapidkey.rb"

if test "$DRY_RUN" -eq 0; then
    test -f "$ZIP_PATH" || { echo "Missing $ZIP_PATH" >&2; exit 1; }
    test -f "$CASK_PATH" || { echo "Missing $CASK_PATH" >&2; exit 1; }
fi

SHA256="(dry-run)"
if test "$DRY_RUN" -eq 0 && test -f "$CASK_PATH"; then
    SHA256="$(grep 'sha256' "$CASK_PATH" | head -1 | sed -E 's/.*sha256 "([^"]+)".*/\1/')"
fi

echo "Committing rapidkey..."
run git add "$PBXPROJ_RELATIVE"
run git commit -m "Release v$VERSION"
run git tag "v$VERSION"

if test "$SKIP_PUSH" -eq 0; then
    echo "Pushing rapidkey..."
    run git push origin HEAD
    run git push origin "v$VERSION"

    echo "Creating GitHub release..."
    run gh release create "v$VERSION" "$ZIP_PATH" \
        --repo "$GITHUB_REPO" \
        --title "v$VERSION" \
        --notes "$NOTES"
else
    echo "Skipping git push and GitHub release (--skip-push)"
fi

echo "Updating homebrew-tap..."
run cp "$CASK_PATH" "$HOMEBREW_TAP_DIR/Casks/rapidkey.rb"

if test "$NO_PIN" -eq 0; then
    if test "$DRY_RUN" -eq 1; then
        echo "[dry-run] (cd $HOMEBREW_TAP_DIR && ./pin.sh)"
    else
        (cd "$HOMEBREW_TAP_DIR" && ./pin.sh)
    fi
else
    echo "Skipping pin.sh (--no-pin)"
fi

if test "$DRY_RUN" -eq 1; then
    echo "[dry-run] (cd $HOMEBREW_TAP_DIR && git add Casks/ && git commit -m 'rapidkey $VERSION')"
else
    (
        cd "$HOMEBREW_TAP_DIR"
        git add Casks/
        git commit -m "rapidkey $VERSION"
    )
fi

if test "$SKIP_PUSH" -eq 0; then
    echo "Pushing homebrew-tap..."
    run bash -c "cd '$HOMEBREW_TAP_DIR' && git push origin main"
else
    echo "Skipping homebrew-tap push (--skip-push)"
fi

echo
echo "Published RapidKey v$VERSION"
echo "  sha256: $SHA256"
echo "  release: https://github.com/$GITHUB_REPO/releases/tag/v$VERSION"
echo "  users:   brew update && brew upgrade --cask ivalkou/tap/rapidkey"
if test -e /Applications/RapidKey.app; then
    echo
    echo "If brew upgrade fails because RapidKey.app already exists:"
    echo "  brew upgrade --cask --force ivalkou/tap/rapidkey"
    echo "  # or: rm -rf /Applications/RapidKey.app && brew install --cask ivalkou/tap/rapidkey"
fi
