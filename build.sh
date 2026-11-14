#!/bin/bash
# Baut Schneetag.app. Aufruf: ./build.sh [Ziel.app]
#   UNIVERSAL=1 ./build.sh    baut für Apple-Silicon- und Intel-Macs zugleich
#   SCHNEETAG_DEV=1 ./build.sh  mit Türchen-Testmodus für die Entwicklung
#   SIGN_IDENTITY="Developer ID Application: …" ./build.sh  signiert für die Verteilung
set -euo pipefail
source_dir="$(cd "$(dirname "$0")" && pwd)"
bundle="${1:-$source_dir/build/Schneetag.app}"
sources=(main.swift BannerFrost.swift FestiveCursor.swift HeavyPlow.swift SnowWorkshop.swift SnowmanArt.swift
         SleighArt.swift Advent.swift SnowballFight.swift ChristmasScene.swift)
paths=()
for file in "${sources[@]}"; do paths+=("$source_dir/$file"); done
dev=""
if [[ "${SCHNEETAG_DEV:-0}" == 1 ]]; then dev="-DSCHNEETAG_DEV"; fi
if [[ "${UNIVERSAL:-0}" == 1 ]]; then
    archs=(arm64 x86_64)
else
    case "$(uname -m)" in
        arm64|x86_64) archs=("$(uname -m)") ;;
        *) echo "Diese Architektur wird nicht unterstützt." >&2; exit 1 ;;
    esac
fi
mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources"
work="$(mktemp -d "${TMPDIR:-/tmp}/schneetag-build.XXXXXX")"
trap 'rm -rf "$work"' EXIT
binaries=()
for arch in "${archs[@]}"; do
    xcrun swiftc -O $dev -target "$arch-apple-macosx14.0" "${paths[@]}" -o "$work/Schneetag-$arch"
    binaries+=("$work/Schneetag-$arch")
done
if [[ ${#binaries[@]} -gt 1 ]]; then
    lipo -create "${binaries[@]}" -output "$bundle/Contents/MacOS/Schneetag"
else
    cp "${binaries[0]}" "$bundle/Contents/MacOS/Schneetag"
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
