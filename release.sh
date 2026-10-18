#!/bin/zsh
# release.sh -- package the redistributable app for both Mac architectures.
# Created by LT Sean Egan, PhD 2026-10-15
set -euo pipefail
project_dir=${0:A:h}
version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$project_dir/Info.plist")
app_dir="$project_dir/build/release/Typing Sounds.app"
APP_DIR="$app_dir" INCLUDE_PERSONAL_SOUNDS=0 "$project_dir/build.sh"
"$app_dir/Contents/MacOS/TypingSounds" --self-test
codesign --verify --deep --strict "$app_dir"
mkdir -p "$project_dir/dist"
archive="$project_dir/dist/Typing-Sounds-$version-universal.zip"
ditto -c -k --sequesterRsrc --keepParent "$app_dir" "$archive"
(cd "$project_dir/dist" && shasum -a 256 "${archive:t}") > "$archive.sha256"
echo "$archive"
