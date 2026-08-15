#!/bin/bash
# Developer ID 签名 + Apple 公证。缺少 secrets 时自动跳过（产出未签名构建）。
# 需要的仓库 secrets：
#   MACOS_CERT_P12         Developer ID Application 证书 .p12（base64）
#   MACOS_CERT_PASSWORD    .p12 导出密码（可为空）
#   ASC_KEY_P8             App Store Connect API 密钥 .p8（base64，App Manager 角色）
#   ASC_KEY_ID             密钥 ID
#   ASC_ISSUER_ID          发行者 ID
set -euo pipefail

APP="CameraToggle.app"

if [ -z "${MACOS_CERT_P12:-}" ]; then
  echo "::warning::未配置签名 secrets，跳过签名/公证（未签名构建）"
  exit 0
fi

# --- 1. 临时钥匙串导入证书 ---
KEYCHAIN="build-signing.keychain-db"
KEYCHAIN_PASS="$(openssl rand -hex 32)"
cleanup() {
  security delete-keychain "$KEYCHAIN" 2>/dev/null || true
  rm -f cert.p12 asc.p8 notary.zip
}
trap cleanup EXIT

security create-keychain -p "$KEYCHAIN_PASS" "$KEYCHAIN"
security list-keychains -d user -s "$KEYCHAIN" $(security list-keychains -d user | tr -d '"')
security set-keychain-settings "$KEYCHAIN"
security unlock-keychain -p "$KEYCHAIN_PASS" "$KEYCHAIN"

printf '%s' "$MACOS_CERT_P12" | base64 --decode > cert.p12
security import cert.p12 -k "$KEYCHAIN" -P "${MACOS_CERT_PASSWORD:-}" -T /usr/bin/codesign
security set-key-partition-list -S apple-tool:,apple: -s -k "$KEYCHAIN_PASS" "$KEYCHAIN"

IDENTITY="$(security find-identity -v -p codesigning "$KEYCHAIN" \
    | grep "Developer ID Application" | head -1 | sed -E 's/^.*"(.*)".*$/\1/')"
if [ -z "$IDENTITY" ]; then
  echo "::error::钥匙串中找不到 Developer ID Application 证书"
  exit 1
fi
echo "Signing with: $IDENTITY"

# --- 2. 签名（Hardened Runtime + 安全时间戳，公证必需） ---
codesign --force --deep --options runtime --timestamp --sign "$IDENTITY" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

# --- 3. 公证 + 装订（需 App Store Connect 密钥） ---
if [ -n "${ASC_KEY_P8:-}" ]; then
  printf '%s' "$ASC_KEY_P8" | base64 --decode > asc.p8
  ditto -c -k --keepParent "$APP" notary.zip
  xcrun notarytool submit notary.zip \
      --key asc.p8 --key-id "$ASC_KEY_ID" --issuer "$ASC_ISSUER_ID" --wait
  xcrun stapler staple "$APP"
  xcrun stapler validate "$APP"
  echo "✅ 已签名并公证"
else
  echo "::warning::缺少 App Store Connect 密钥，已签名但未公证"
fi
