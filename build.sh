#!/bin/bash
# 编译 CameraToggle 并打包为 .app（含图标）
set -euo pipefail
cd "$(dirname "$0")"

APP="CameraToggle.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

# 通用二进制（Apple Silicon + Intel），macOS 13+
swiftc -O -swift-version 5 -target arm64-apple-macos13.0 \
    main.swift Guide.swift L10n.swift -o "$APP/Contents/MacOS/CameraToggle.arm64"
swiftc -O -swift-version 5 -target x86_64-apple-macos13.0 \
    main.swift Guide.swift L10n.swift -o "$APP/Contents/MacOS/CameraToggle.x86_64"
lipo -create -output "$APP/Contents/MacOS/CameraToggle" \
    "$APP/Contents/MacOS/CameraToggle.arm64" "$APP/Contents/MacOS/CameraToggle.x86_64"
rm "$APP/Contents/MacOS/CameraToggle.arm64" "$APP/Contents/MacOS/CameraToggle.x86_64"

if [ -f AppIcon.icns ]; then
    mkdir -p "$APP/Contents/Resources"
    cp AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
fi

cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>CameraToggle</string>
    <key>CFBundleDisplayName</key>
    <string>CameraToggle</string>
    <key>CFBundleIdentifier</key>
    <string>local.cameratoggle.app</string>
    <key>CFBundleExecutable</key>
    <string>CameraToggle</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF

# 让 Finder 立即刷新图标缓存
touch "$APP"

echo "已构建 $APP"
