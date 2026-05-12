#!/bin/bash
set -e

APP_NAME="SteamControllerMacKana"
APP_DIR="${APP_NAME}.app/Contents"

echo "Building..."
swift build -c release

echo "Creating .app bundle..."
rm -rf "${APP_NAME}.app"
mkdir -p "${APP_DIR}/MacOS"

cp ".build/release/${APP_NAME}" "${APP_DIR}/MacOS/"

cat > "${APP_DIR}/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.ottotto0123.SteamControllerMacKana</string>
    <key>CFBundleName</key>
    <string>SteamControllerMacKana</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSAccessibilityUsageDescription</key>
    <string>Steamのキーボードイベントを横取りするためにアクセシビリティ権限が必要です。</string>
</dict>
</plist>
EOF

echo "Done: ${APP_NAME}.app"
echo "To install: drag to /Applications"
