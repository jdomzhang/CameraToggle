#!/bin/bash
# 发版后更新 Homebrew tap 里的 Cask 版本与校验和
# 用法: ./update-tap.sh <版本号>    例: ./update-tap.sh v1.0.5
set -euo pipefail

VERSION="${1:?用法: ./update-tap.sh <版本号，如 v1.0.5>}"
ZIP_URL="https://github.com/jdomzhang/CameraToggle/releases/download/${VERSION}/CameraToggle-${VERSION}-macOS-universal.zip"

echo "计算 ${VERSION} 的 sha256 …"
SHA=$(curl -fsL "$ZIP_URL" | shasum -a 256 | awk '{print $1}')

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
git clone -q git@github.com:jdomzhang/homebrew-tap.git "$WORK/tap"

sed -E -i '' "s/version \"[^\"]+\"/version \"${VERSION#v}\"/; s/sha256 \"[a-f0-9]{64}\"/sha256 \"$SHA\"/" \
    "$WORK/tap/Casks/cameratoggle.rb"
(cd "$WORK/tap" && git commit -aqm "CameraToggle ${VERSION}" && git push -q)

echo "✅ tap 已更新：brew upgrade cameratoggle 即可获得 ${VERSION}"
