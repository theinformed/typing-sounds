#!/bin/zsh
# release.sh -- package the redistributable app for Apple silicon Macs.
# Created by LT Sean Egan, PhD 2026-10-15
# Modified: SDE 2026-11-04 package drag-to-Applications DMG and verify isolated models.
set -euo pipefail
project_dir=${0:A:h}
version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$project_dir/Info.plist")
app_dir="$project_dir/build/release/Typing Sounds.app"
if [[ ${SKIP_BUILD:-0} != 1 ]]; then
  APP_DIR="$app_dir" INCLUDE_PERSONAL_SOUNDS=0 ARCHS=arm64 "$project_dir/build.sh"
fi
swiftc "$project_dir/Sources/Models.swift" "$project_dir/Tests/ModelsTests.swift" \
  -o "$project_dir/build/models-test"
"$project_dir/build/models-test"
"$app_dir/Contents/MacOS/TypingSounds" --self-test
"$app_dir/Contents/MacOS/TypingSounds" --settings-self-test
codesign --verify --deep --strict "$app_dir"
mkdir -p "$project_dir/dist"
archive="$project_dir/dist/Typing-Sounds-$version-apple-silicon.zip"
ditto -c -k --sequesterRsrc --keepParent "$app_dir" "$archive"
(cd "$project_dir/dist" && shasum -a 256 "${archive:t}") > "$archive.sha256"
image="$project_dir/dist/Typing-Sounds-$version-apple-silicon.dmg"
image_stage=$(mktemp -d /private/tmp/typingsounds-dmg.XXXXXX)
trap 'rm -rf "$image_stage"' EXIT
ditto "$app_dir" "$image_stage/Typing Sounds.app"
ln -s /Applications "$image_stage/Applications"
hdiutil create -quiet -volname 'Typing Sounds' -srcfolder "$image_stage" -ov -format UDZO "$image"
if [[ -n ${SIGN_IDENTITY:-} ]]; then
  codesign --sign "$SIGN_IDENTITY" --timestamp "$image"
fi
(cd "$project_dir/dist" && shasum -a 256 "${image:t}") > "$image.sha256"
echo "$archive"
echo "$image"
