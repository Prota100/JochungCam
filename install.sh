#!/bin/bash
# 조청캠 (JochungCam) for Mac — 원클릭 설치
# bash <(curl -fsSL https://raw.githubusercontent.com/Prota100/JochungCam/main/install.sh)

set -e

echo ""
echo "  🍯 조청캠 (JochungCam) for Mac"
echo "  ─────────────────────────────"
echo ""

# ── Xcode CLI Tools ──
if ! xcode-select -p &>/dev/null; then
    echo "  📎 Xcode Command Line Tools 설치가 필요합니다."
    xcode-select --install
    echo "  ⏳ 설치 완료 후 다시 실행하세요."
    exit 1
fi

# ── Homebrew ──
if ! command -v brew &>/dev/null; then
    echo "  🍺 Homebrew 설치 중..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    [ -f /opt/homebrew/bin/brew ] && eval "$(/opt/homebrew/bin/brew shellenv)"
fi

if ! command -v brew &>/dev/null; then
    echo "  ❌ Homebrew를 찾을 수 없습니다. https://brew.sh"
    exit 1
fi

# ── 의존성 ──
echo "  📦 의존성 설치..."
for pkg in libimagequant gifski webp; do
    if brew list "$pkg" &>/dev/null; then
        echo "     ✅ $pkg"
    else
        echo "     ⬇️  $pkg..."
        brew install "$pkg" 2>/dev/null
        echo "     ✅ $pkg"
    fi
done
echo ""

# ── 소스 빌드 ──
echo "  🔨 빌드 중... (1~2분)"
BUILD_DIR=$(mktemp -d)
trap "rm -rf $BUILD_DIR" EXIT

git clone --depth 1 --quiet https://github.com/Prota100/JochungCam.git "$BUILD_DIR/src"
cd "$BUILD_DIR/src"

if ! swift build -c release 2>&1 | grep -q "Build complete"; then
    echo "  ❌ 빌드 실패:"
    swift build -c release 2>&1 | tail -10
    exit 1
fi
echo "  ✅ 빌드 완료"
echo ""

# ── .app 번들 ──
APP="$BUILD_DIR/JochungCam.app"
mkdir -p "$APP/Contents/MacOS"

cp ".build/arm64-apple-macosx/release/JochungCam" "$APP/Contents/MacOS/"

cat > "$APP/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>JochungCam</string>
    <key>CFBundleIdentifier</key><string>com.prota100.jochungcam</string>
    <key>CFBundleName</key><string>JochungCam</string>
    <key>CFBundleDisplayName</key><string>조청캠</string>
    <key>CFBundleVersion</key><string>1.0</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSScreenCaptureUsageDescription</key><string>화면 캡처를 위해 권한이 필요합니다.</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key>
            <string>Media</string>
            <key>CFBundleTypeRole</key>
            <string>Editor</string>
            <key>LSHandlerRank</key>
            <string>Alternate</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>public.movie</string>
                <string>public.video</string>
                <string>com.apple.quicktime-movie</string>
                <string>public.image</string>
                <string>com.compuserve.gif</string>
                <string>org.webmproject.webp</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP" 2>/dev/null || true
xattr -cr "$APP"

# ── 설치 ──
[ -d /Applications/JochungCam.app ] && rm -rf /Applications/JochungCam.app
cp -R "$APP" /Applications/

echo ""
echo "  ✅ 설치 완료!"
echo "  ─────────────────────────────"
echo "  실행:   open /Applications/JochungCam.app"
echo "  단축키: ⌘⇧G"
echo ""

if [ -t 0 ]; then
    read -p "  지금 실행? (Y/n) " -n 1 -r
    echo
    [[ ! $REPLY =~ ^[Nn]$ ]] && open /Applications/JochungCam.app
else
    open /Applications/JochungCam.app
fi
