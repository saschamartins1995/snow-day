#!/bin/bash
# Builds Snow Day.app. Usage: ./build.sh [Target.app]
#   UNIVERSAL=1 ./build.sh     builds for Apple silicon and Intel Macs at once
#   SNOWDAY_DEV=1 ./build.sh   adds the door test mode for development
#   SIGN_IDENTITY="Developer ID Application: …" ./build.sh   signs for distribution
set -euo pipefail
source_dir="$(cd "$(dirname "$0")" && pwd)"
bundle="${1:-$source_dir/build/Snow Day.app}"
sources=(main.swift BannerFrost.swift FestiveCursor.swift HeavyPlow.swift SnowWorkshop.swift SnowmanArt.swift
         SleighArt.swift Advent.swift SnowballFight.swift ChristmasScene.swift)
paths=()
for file in "${sources[@]}"; do paths+=("$source_dir/$file"); done
dev=""
if [[ "${SNOWDAY_DEV:-0}" == 1 ]]; then dev="-DSNOWDAY_DEV"; fi
if [[ "${UNIVERSAL:-0}" == 1 ]]; then
    archs=(arm64 x86_64)
else
    case "$(uname -m)" in
        arm64|x86_64) archs=("$(uname -m)") ;;
        *) echo "This architecture is not supported." >&2; exit 1 ;;
    esac
fi
mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources"
work="$(mktemp -d "${TMPDIR:-/tmp}/snowday-build.XXXXXX")"
trap 'rm -rf "$work"' EXIT
binaries=()
for arch in "${archs[@]}"; do
    xcrun swiftc -O $dev -target "$arch-apple-macosx14.0" "${paths[@]}" -o "$work/SnowDay-$arch"
    binaries+=("$work/SnowDay-$arch")
done
if [[ ${#binaries[@]} -gt 1 ]]; then
    lipo -create "${binaries[@]}" -output "$bundle/Contents/MacOS/SnowDay"
else
    cp "${binaries[0]}" "$bundle/Contents/MacOS/SnowDay"
fi
cp "$source_dir/Info.plist" "$bundle/Contents/Info.plist"
cp "$source_dir/Resources/AppIcon.icns" "$bundle/Contents/Resources/AppIcon.icns"
if [[ -n "${SIGN_IDENTITY:-}" ]]; then
    # Developer ID with the hardened runtime and a secure timestamp, as
    # Apple's notary service requires.
    codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$bundle"
else
    codesign --force --sign - "$bundle"
fi
