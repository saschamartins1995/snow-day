#!/bin/bash
# Builds, signs and notarizes a release: build/SnowDay.zip, ready to upload.
#
# Needs a "Developer ID Application" certificate in the keychain and stored
# notary credentials, created once with:
#   xcrun notarytool store-credentials snowday --apple-id <Apple ID> --team-id <Team ID>
#
# Usage: SIGN_IDENTITY="Developer ID Application: Name (TEAMID)" tools/release.sh
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
profile="${NOTARY_PROFILE:-snowday}"
app="$root/build/Snow Day.app"
zip="$root/build/SnowDay.zip"
: "${SIGN_IDENTITY:?Set SIGN_IDENTITY to your Developer ID Application identity}"
rm -rf "$app" "$zip"
UNIVERSAL=1 SIGN_IDENTITY="$SIGN_IDENTITY" "$root/build.sh" "$app"
codesign --verify --deep --strict "$app"
ditto -c -k --norsrc --noextattr --keepParent "$app" "$zip"
xcrun notarytool submit "$zip" --keychain-profile "$profile" --wait
xcrun stapler staple "$app"
rm "$zip"
ditto -c -k --norsrc --noextattr --keepParent "$app" "$zip"
spctl --assess --type execute --verbose "$app"
echo "Ready: $zip"
