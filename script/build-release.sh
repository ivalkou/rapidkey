#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

build_version="0.0.0-SNAPSHOT"
codesign_identity="-"

while test $# -gt 0; do
    case $1 in
        --build-version) build_version="$2"; shift 2;;
        --codesign-identity) codesign_identity="$2"; shift 2;;
        *) echo "Unknown option $1" >&2; exit 1;;
    esac
done

if grep -q SNAPSHOT <<< "$build_version"; then
    echo "Refusing to build SNAPSHOT version for release" >&2
    exit 1
fi

xcode_configuration="Release"
rm -rf .release .xcode-build
mkdir -p .release

echo "Building RapidKey $build_version (arm64)..."
xcodebuild -project RapidKey.xcodeproj \
    -scheme RapidKey \
    -destination 'generic/platform=macOS' \
    -configuration "$xcode_configuration" \
    -derivedDataPath .xcode-build \
    ARCHS=arm64 ONLY_ACTIVE_ARCH=NO \
    clean build

app_src=".xcode-build/Build/Products/$xcode_configuration/RapidKey.app"
if ! test -d "$app_src"; then
    echo "Expected app at $app_src" >&2
    exit 1
fi

release_dir=".release/RapidKey-v$build_version"
mkdir -p "$release_dir"
cp -R "$app_src" "$release_dir/RapidKey.app"

echo "Signing RapidKey.app (identity: $codesign_identity)..."
codesign --force --deep -s "$codesign_identity" "$release_dir/RapidKey.app"
codesign -v "$release_dir/RapidKey.app"

arch=$(lipo -info "$release_dir/RapidKey.app/Contents/MacOS/RapidKey" 2>/dev/null | awk '{print $NF}' || file "$release_dir/RapidKey.app/Contents/MacOS/RapidKey")
echo "Binary arch: $arch"
if ! grep -q arm64 <<< "$arch"; then
    echo "Expected arm64 binary" >&2
    exit 1
fi

echo "Packing zip..."
(cd .release && zip -r "RapidKey-v$build_version.zip" "RapidKey-v$build_version")

./script/build-brew-cask.sh \
    --cask-name rapidkey \
    --zip-uri ".release/RapidKey-v$build_version.zip" \
    --build-version "$build_version"

echo "Done:"
echo "  .release/RapidKey-v$build_version.zip"
echo "  .release/rapidkey.rb"
