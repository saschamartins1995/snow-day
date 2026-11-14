#!/bin/bash
# Builds, signs and notarizes a release: build/Schneetag.zip, ready to upload.
#
# Needs a "Developer ID Application" certificate in the keychain and stored
# notary credentials, created once with:
#   xcrun notarytool store-credentials schneetag --apple-id <Apple ID> --team-id <Team ID>
#
# Usage: SIGN_IDENTITY="Developer ID Application: Name (TEAMID)" tools/release.sh
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
profile="${NOTARY_PROFILE:-schneetag}"
: "${SIGN_IDENTITY:?Set SIGN_IDENTITY to your Developer ID Application identity}"
rm -rf "$root/build/Schneetag.app" "$root/build/Schneetag.zip"
UNIVERSAL=1 SIGN_IDENTITY="$SIGN_IDENTITY" "$root/build.sh" "$root/build/Schneetag.app"
codesign --verify --deep --strict "$root/build/Schneetag.app"
ditto -c -k --keepParent "$root/build/Schneetag.app" "$root/build/Schneetag.zip"
xcrun notarytool submit "$root/build/Schneetag.zip" --keychain-profile "$profile" --wait
xcrun stapler staple "$root/build/Schneetag.app"
rm "$root/build/Schneetag.zip"
ditto -c -k --keepParent "$root/build/Schneetag.app" "$root/build/Schneetag.zip"
spctl --assess --type execute --verbose "$root/build/Schneetag.app"
echo "Ready: $root/build/Schneetag.zip"
