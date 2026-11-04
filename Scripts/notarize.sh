#!/bin/zsh
# notarize.sh -- submit an intentionally signed direct release and staple its ticket.
# Created by LT Sean Egan, PhD 2026-11-04
set -euo pipefail
project_dir=${0:A:h:h}
app="$project_dir/build/release/Typing Sounds.app"
version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app/Contents/Info.plist")
archive="$project_dir/dist/Typing-Sounds-$version-apple-silicon.zip"
: "${NOTARY_PROFILE:?Set NOTARY_PROFILE to an existing owner Keychain notarization profile}"
codesign --verify --deep --strict "$app"
signature=$(codesign -dv --verbose=4 "$app" 2>&1)
if [[ "$signature" != *'Authority=Developer ID Application:'* || "$signature" != *runtime* ]]; then
  echo 'Build with a Developer ID Application identity and hardened runtime first.' >&2
  exit 1
fi
result=$(xcrun notarytool submit "$archive" --keychain-profile "$NOTARY_PROFILE" --wait --output-format json)
notary_status=$(printf '%s' "$result" | plutil -extract status raw -o - -)
if [[ "$notary_status" != Accepted ]]; then
  echo "Apple notarization status: $notary_status" >&2
  exit 1
fi
xcrun stapler staple "$app"
xcrun stapler validate "$app"
SKIP_BUILD=1 "$project_dir/release.sh"
