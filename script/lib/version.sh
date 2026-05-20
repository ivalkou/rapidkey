#!/bin/bash
# Version helpers for RapidKey release scripts.

PBXPROJ_RELATIVE="RapidKey.xcodeproj/project.pbxproj"

read_marketing_version() {
    local pbxproj="$1"
    grep -m1 'MARKETING_VERSION = ' "$pbxproj" | sed -E 's/.*MARKETING_VERSION = ([^;]+);/\1/'
}

read_build_number() {
    local pbxproj="$1"
    grep -m1 'CURRENT_PROJECT_VERSION = ' "$pbxproj" | sed -E 's/.*CURRENT_PROJECT_VERSION = ([^;]+);/\1/'
}

validate_semver() {
    local version="$1"
    if ! grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$' <<< "$version"; then
        echo "Invalid semver (expected MAJOR.MINOR.PATCH): $version" >&2
        return 1
    fi
}

bump_semver() {
    local version="$1"
    local kind="$2"
    validate_semver "$version" || return 1

    local major minor patch
    IFS=. read -r major minor patch <<< "$version"

    case "$kind" in
        patch) patch=$((patch + 1));;
        minor) minor=$((minor + 1)); patch=0;;
        major) major=$((major + 1)); minor=0; patch=0;;
        *)
            echo "Unknown bump kind: $kind (use patch, minor, or major)" >&2
            return 1
            ;;
    esac

    echo "${major}.${minor}.${patch}"
}

set_xcode_versions() {
    local pbxproj="$1"
    local marketing_version="$2"
    local build_number="$3"

    validate_semver "$marketing_version" || return 1
    if ! grep -qE '^[0-9]+$' <<< "$build_number"; then
        echo "Invalid build number: $build_number" >&2
        return 1
    fi

    sed -i '' \
        -e "s/MARKETING_VERSION = [^;]*;/MARKETING_VERSION = $marketing_version;/g" \
        -e "s/CURRENT_PROJECT_VERSION = [^;]*;/CURRENT_PROJECT_VERSION = $build_number;/g" \
        "$pbxproj"
}
