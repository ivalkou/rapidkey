# Releasing RapidKey

Guide for maintainers: version bumps, GitHub Releases, and Homebrew tap updates.

## Prerequisites

- macOS on Apple Silicon with Xcode
- `git`, `gh` (authenticated)
- [homebrew-tap](https://github.com/ivalkou/homebrew-tap) cloned next to this repo:

  ```
  code/
    RapidKey/
    homebrew-tap/
  ```

## Publish a release (recommended)

One command bumps Xcode versions, builds, creates a GitHub Release, and updates the tap:

```bash
# Patch release: 0.1.0 → 0.1.1 (also increments CURRENT_PROJECT_VERSION)
./script/publish-release.sh --bump patch --yes

# Explicit version with release notes
./script/publish-release.sh --version 0.2.0 --notes "Fix palette focus"

# Preview steps without changing anything
./script/publish-release.sh --bump minor --dry-run
```

### Options

| Flag | Effect |
|------|--------|
| `--version X.Y.Z` | Set `MARKETING_VERSION` explicitly |
| `--bump patch\|minor\|major` | Bump from current version in `project.pbxproj` |
| `--notes TEXT` | GitHub release notes (default: short template) |
| `--yes` | Skip confirmation prompt |
| `--dry-run` | Print steps only |
| `--skip-push` | Commit locally, no `git push` / no tap push |
| `--no-pin` | Do not create `rapidkey@X.Y.Z.rb` in tap |
| `--allow-dirty` | Allow uncommitted changes in the working tree |

### What the script does

1. Bump `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in [RapidKey.xcodeproj/project.pbxproj](../RapidKey.xcodeproj/project.pbxproj)
2. Run [script/build-release.sh](../script/build-release.sh) (arm64, ad-hoc sign, zip)
3. Commit, tag `vX.Y.Z`, push to `ivalkou/rapidkey`
4. `gh release create` with `RapidKey-vX.Y.Z.zip`
5. Copy `.release/rapidkey.rb` to `../homebrew-tap/Casks/rapidkey.rb`, run `pin.sh`, push tap

Artifacts are gitignored under `.release/` and `.xcode-build/`.

## Release build only

Build zip and cask file without publishing:

```bash
./script/build-release.sh --build-version 0.2.0
```

Produces:

- `.release/RapidKey-v0.2.0.zip`
- `.release/rapidkey.rb`

Then publish manually: tag, `gh release create`, copy cask to homebrew-tap.

## Manual release checklist

If not using `publish-release.sh`:

1. Set `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in Xcode
2. `./script/build-release.sh --build-version X.Y.Z`
3. `git tag vX.Y.Z && git push origin vX.Y.Z`
4. `gh release create vX.Y.Z .release/RapidKey-vX.Y.Z.zip --title "vX.Y.Z"`
5. Copy `.release/rapidkey.rb` → `homebrew-tap/Casks/rapidkey.rb`, commit, push
6. Optional: `cd ../homebrew-tap && ./pin.sh` for `rapidkey@X.Y.Z.rb`

Release asset name must match the cask URL: `RapidKey-vX.Y.Z.zip`, tag `vX.Y.Z`.

## User upgrades

```bash
brew update && brew upgrade --cask ivalkou/tap/rapidkey
```

If Homebrew reports an existing app at `/Applications/RapidKey.app` (e.g. from a local Xcode build):

```bash
brew upgrade --cask --force ivalkou/tap/rapidkey
# or
rm -rf /Applications/RapidKey.app && brew install --cask ivalkou/tap/rapidkey
```

## Notes

- Releases are **not notarized**; the Homebrew cask removes `com.apple.quarantine` in `postflight`
- Builds are **arm64 only** (no Intel Mac support via Homebrew)
- Scripts: [script/publish-release.sh](../script/publish-release.sh), [script/lib/version.sh](../script/lib/version.sh)
