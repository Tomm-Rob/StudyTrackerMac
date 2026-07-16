#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build/scratch"
APP_DIR="$ROOT_DIR/dist/Study Tracker.app"
EXECUTABLE="$BUILD_DIR/arm64-apple-macosx/debug/StudyTracker"
ICON_BUILD_DIR="$ROOT_DIR/.build/icon"
ICONSET_DIR="$ICON_BUILD_DIR/StudyTrackerIcon.iconset"
ICON_FILE="$ICON_BUILD_DIR/StudyTrackerIcon.icns"
ICON_PREVIEW="$ROOT_DIR/Assets/StudyTrackerIcon.png"

cd "$ROOT_DIR"

mkdir -p "$ROOT_DIR/.build/cache/clang" "$ROOT_DIR/.build/cache/swiftpm"
mkdir -p "$ICON_BUILD_DIR"

SWIFTPM_HOME="$ROOT_DIR/.build/cache/swiftpm" \
CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/cache/clang" \
swift build --disable-sandbox --scratch-path "$BUILD_DIR"

CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/cache/clang" \
swift "$ROOT_DIR/scripts/generate-icon.swift" "$ICONSET_DIR" "$ICON_PREVIEW" "$ICON_FILE"
xattr -cr "$ICONSET_DIR"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$EXECUTABLE" "$APP_DIR/Contents/Resources/StudyTrackerBinary"
cp "$ICON_FILE" "$APP_DIR/Contents/Resources/StudyTrackerIcon.icns"
cc "$ROOT_DIR/scripts/launcher.c" -o "$APP_DIR/Contents/MacOS/StudyTracker"

cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>StudyTracker</string>
    <key>CFBundleIdentifier</key>
    <string>local.study-tracker.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleIconFile</key>
    <string>StudyTrackerIcon</string>
    <key>CFBundleName</key>
    <string>Study Tracker</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
PLIST

printf 'APPL????' > "$APP_DIR/Contents/PkgInfo"
xattr -cr "$APP_DIR"

echo "Packaged: $APP_DIR"
