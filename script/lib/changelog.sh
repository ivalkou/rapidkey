#!/bin/bash
# Changelog helpers for RapidKey release scripts.

# Print the git ref for the previous release (e.g. v0.1.1), or empty if none.
find_previous_release_ref() {
    local marketing_version="$1"
    local tag="v$marketing_version"

    if git rev-parse "$tag" >/dev/null 2>&1; then
        echo "$tag"
        return 0
    fi

    git tag -l 'v[0-9]*.[0-9]*.[0-9]*' --sort=-v:refname 2>/dev/null | head -1
}

# Print markdown bullet lines for commits since REF (excludes "Release v*" commits).
changelog_commits_markdown() {
    local since_ref="${1:-}"
    local commits=""

    if test -n "$since_ref"; then
        commits="$(git log "${since_ref}..HEAD" --no-merges --pretty=format:%s 2>/dev/null \
            | grep -vE '^Release v[0-9]+\.[0-9]+\.[0-9]+$' || true)"
    else
        commits="$(git log --no-merges --pretty=format:%s 2>/dev/null \
            | grep -vE '^Release v[0-9]+\.[0-9]+\.[0-9]+$' || true)"
    fi

    if test -z "$commits"; then
        echo "- _(no commits since previous release)_"
        return 0
    fi

    while IFS= read -r line; do
        test -n "$line" || continue
        echo "- $line"
    done <<< "$commits"
}

# Print full GitHub release notes for VERSION since PREVIOUS_MARKETING.
generate_release_notes() {
    local version="$1"
    local previous_marketing="$2"
    local since_ref
    since_ref="$(find_previous_release_ref "$previous_marketing")"

    local changes
    changes="$(changelog_commits_markdown "$since_ref")"

    cat <<EOF
RapidKey v$version

## Changes

$changes

Install or upgrade via Homebrew:

\`\`\`bash
brew update && brew upgrade --cask ivalkou/tap/rapidkey
\`\`\`
EOF
}
