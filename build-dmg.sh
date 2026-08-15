#!/bin/bash
# 打包 CameraToggle 安装 DMG（需先 ./build.sh 产出 CameraToggle.app）
# 用法: ./build-dmg.sh <版本号>   →  CameraToggle-<版本号>-macOS-universal.dmg
set -euo pipefail
cd "$(dirname "$0")"

VERSION="${1:?用法: ./build-dmg.sh <版本号>，如 v1.0.4}"
DMG="CameraToggle-${VERSION}-macOS-universal.dmg"

STAGING=$(mktemp -d)
trap 'rm -rf "$STAGING"' EXIT
cp .github/dmg-template/.DS_Store "$STAGING/"
mkdir -p "$STAGING/.background"
cp .github/dmg-template/.background/bg.png "$STAGING/.background/"
cp -R CameraToggle.app "$STAGING/"
ln -s /Applications "$STAGING/Applications"

rm -f "$DMG"
hdiutil create -volname CameraToggle -srcfolder "$STAGING" -ov -format UDZO "$DMG" >/dev/null
echo "已生成 $DMG"
