#!/bin/bash
set -e
cd "$(dirname "$0")"
APP="./AI Sleep.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc -O main.swift -o "$APP/Contents/MacOS/AISleep"

# Иконка из logo.jpg (sips + iconutil — оба встроены в macOS)
if [ -f logo.jpg ]; then
  SET=$(mktemp -d)/AppIcon.iconset
  mkdir -p "$SET"
  for s in 16 32 128 256 512; do
    sips -s format png -z $s $s logo.jpg --out "$SET/icon_${s}x${s}.png" > /dev/null
    sips -s format png -z $((s*2)) $((s*2)) logo.jpg --out "$SET/icon_${s}x${s}@2x.png" > /dev/null
  done
  iconutil -c icns "$SET" -o "$APP/Contents/Resources/AppIcon.icns"
  rm -rf "$(dirname "$SET")"
fi
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>AI Sleep</string>
  <key>CFBundleIdentifier</key><string>local.aisleep</string>
  <key>CFBundleExecutable</key><string>AISleep</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$APP" 2>/dev/null || true
echo "built: $(cd "$APP" && pwd)"
