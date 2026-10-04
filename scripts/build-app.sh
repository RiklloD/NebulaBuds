#!/bin/bash
# Builds "NebulaBuds.app" into ./build. Uses Xcode's toolchain if installed (SwiftUI macros need it).
set -euo pipefail
cd "$(dirname "$0")/.."

if [ -d /Applications/Xcode.app ] && [ -z "${DEVELOPER_DIR:-}" ]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

swift build -c release --arch arm64
BIN="$(swift build -c release --arch arm64 --show-bin-path)/GalaxyBudsMac"

APP="build/NebulaBuds.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/GalaxyBuds"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"  # regenerate: swift scripts/make-icon.swift

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>NebulaBuds</string>
    <key>CFBundleDisplayName</key><string>NebulaBuds</string>
    <key>CFBundleIdentifier</key><string>dev.rikllod.nebulabuds</string>
    <key>CFBundleExecutable</key><string>GalaxyBuds</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSBluetoothAlwaysUsageDescription</key>
    <string>Galaxy Buds talks to your earbuds over Bluetooth to read battery status and change settings.</string>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP"
echo "Built $APP"

# ./scripts/build-app.sh --install → replace the copy in /Applications (where Raycast/Spotlight find it)
if [ "${1:-}" = "--install" ]; then
    pkill -f "/Applications/NebulaBuds.app" || true
    rm -rf "/Applications/NebulaBuds.app"
    cp -R "$APP" /Applications/
    echo "Installed to /Applications/NebulaBuds.app"
fi
