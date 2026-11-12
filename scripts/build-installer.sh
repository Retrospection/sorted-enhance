#!/bin/bash
set -euo pipefail

output_dir=${1:?Usage: build-installer.sh OUTPUT_DIR [VERSION_TAG]}
tag=${2:-}
mkdir -p "$output_dir"
output_dir=$(cd "$output_dir" && pwd)
cd "$(dirname "$0")/.."

settings=(ONLY_ACTIVE_ARCH=NO "ARCHS=arm64 x86_64")
if [[ -n "$tag" ]]; then
    number='(0|[1-9][0-9]*)'
    pattern="^v($number\\.$number\\.$number)(-(alpha|beta|rc)\\.$number)?$"
    if [[ ! "$tag" =~ $pattern ]]; then
        echo "Expected vX.Y.Z with an optional -alpha.N, -beta.N or -rc.N suffix." >&2
        exit 2
    fi
    settings+=("MARKETING_VERSION=${BASH_REMATCH[1]}" "CURRENT_PROJECT_VERSION=${GITHUB_RUN_NUMBER:-1}")
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
xcodebuild -project SortedEnhance.xcodeproj -scheme SortedEnhance \
    -configuration Release -destination 'generic/platform=macOS' \
    -derivedDataPath "$work/build" "${settings[@]}" build

app="$work/build/Build/Products/Release/SortedEnhance.app"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")
name="SortedEnhance-${tag:-v$version}-macOS-universal.pkg"
productbuild --component "$app" /Applications "$work/$name"
pkgutil --expand-full "$work/$name" "$work/expanded"
binary=$(find "$work/expanded" -path '*/SortedEnhance.app/Contents/MacOS/SortedEnhance' -type f)
lipo "$binary" -verify_arch arm64 x86_64
codesign --verify --strict "${binary%/Contents/MacOS/SortedEnhance}"
mv "$work/$name" "$output_dir/$name"
(cd "$output_dir" && shasum -a 256 "$name" > "$name.sha256")
