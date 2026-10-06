#!/bin/bash
# Собирает AI Sleep.dmg с привычным окном «перетащи в Applications».
# hdiutil встроен в macOS — никаких зависимостей.
set -e
cd "$(dirname "$0")"

[ -d "AI Sleep.app" ] || ./build.sh

STAGE=$(mktemp -d)
cp -R "AI Sleep.app" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

rm -f "AI Sleep.dmg"
hdiutil create -volname "AI Sleep" -srcfolder "$STAGE" -ov -format UDZO -quiet "AI Sleep.dmg"
rm -rf "$STAGE"

echo "built: $(pwd)/AI Sleep.dmg ($(du -h "AI Sleep.dmg" | cut -f1))"
