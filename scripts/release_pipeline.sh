#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP_NAME="JochungCam"
VERSION="${1:-1.0.1}"
ARTIFACT_BASENAME="${APP_NAME}-v${VERSION}-macOS-arm64"
OUT_DIR="$ROOT/release"
LOG_DIR="$OUT_DIR/logs"
BUILD_BIN="$ROOT/.build/arm64-apple-macosx/release/${APP_NAME}"
APP_DIR="$OUT_DIR/${APP_NAME}.app"
ZIP_PATH="$OUT_DIR/${ARTIFACT_BASENAME}.zip"

mkdir -p "$OUT_DIR" "$LOG_DIR"

echo "[1/6] Clean + resolve + build"
swift package clean
swift package resolve | tee "$LOG_DIR/resolve.log"
swift build -c release 2>&1 | tee "$LOG_DIR/build-release.log"

echo "[2/6] Test"
set +e
swift test -c release 2>&1 | tee "$LOG_DIR/test-release.log"
TEST_EXIT=$?
set -e

echo "[3/6] Bundle app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
cp "$BUILD_BIN" "$APP_DIR/Contents/MacOS/$APP_NAME"
cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>${APP_NAME}</string>
<key>CFBundleIdentifier</key><string>com.prota100.jochungcam</string>
<key>CFBundleName</key><string>${APP_NAME}</string>
<key>CFBundleVersion</key><string>${VERSION}</string>
<key>CFBundleShortVersionString</key><string>${VERSION}</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSScreenCaptureUsageDescription</key><string>화면 캡처를 위해 권한이 필요합니다.</string>
</dict></plist>
PLIST
codesign --force --deep --sign - "$APP_DIR" >/dev/null 2>&1 || true
xattr -cr "$APP_DIR" || true

echo "[4/6] Package zip"
rm -f "$ZIP_PATH"
( cd "$OUT_DIR" && /usr/bin/zip -qry "$(basename "$ZIP_PATH")" "$(basename "$APP_DIR")" )

echo "[5/6] Smoke checks"
{
  echo "== binary =="
  file "$BUILD_BIN"
  otool -L "$BUILD_BIN"
  echo
  echo "== app structure =="
  test -f "$APP_DIR/Contents/MacOS/$APP_NAME" && echo "app binary: ok"
  test -f "$APP_DIR/Contents/Info.plist" && echo "plist: ok"
  echo
  echo "== dependency cli presence =="
  command -v gifski && echo "gifski: ok"
  command -v cwebp && echo "cwebp: ok"
  command -v webpmux && echo "webpmux: ok"
  echo
  echo "== zip integrity =="
  unzip -t "$ZIP_PATH" | tail -n 2
} | tee "$LOG_DIR/smoke.log"

echo "[6/6] Checksums"
shasum -a 256 "$BUILD_BIN" "$ZIP_PATH" | tee "$OUT_DIR/SHA256SUMS.txt"

{
  echo "TEST_EXIT=${TEST_EXIT}"
  echo "VERSION=${VERSION}"
  echo "BUILD_BIN=${BUILD_BIN}"
  echo "APP_DIR=${APP_DIR}"
  echo "ZIP_PATH=${ZIP_PATH}"
} | tee "$OUT_DIR/release-metadata.env"

if [[ $TEST_EXIT -ne 0 ]]; then
  echo "Release pipeline completed with test failures (see $LOG_DIR/test-release.log)."
  exit 2
fi

echo "Release pipeline completed successfully."