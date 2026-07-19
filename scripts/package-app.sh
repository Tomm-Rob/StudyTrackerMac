#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build/scratch"
OUTPUT_APP_DIR="$ROOT_DIR/dist/Study Tracker.app"
OUTPUT_ARCHIVE_FILE="$ROOT_DIR/dist/Study Tracker-1.0.0-macOS-arm64.zip"
STAGING_ROOT="$(mktemp -d /private/tmp/study-tracker-package.XXXXXX)"
APP_DIR="$STAGING_ROOT/Study Tracker.app"
ARCHIVE_FILE="$STAGING_ROOT/Study Tracker-1.0.0-macOS-arm64.zip"
EXECUTABLE="$BUILD_DIR/arm64-apple-macosx/release/StudyTracker"
ICON_BUILD_DIR="$ROOT_DIR/.build/icon"
ICONSET_DIR="$ICON_BUILD_DIR/StudyTrackerIcon.iconset"
ICON_FILE="$ICON_BUILD_DIR/StudyTrackerIcon.icns"
ICON_PREVIEW="$ROOT_DIR/Assets/StudyTrackerIcon.png"
DARK_ICON="$ROOT_DIR/Assets/StudyTrackerIcon-Dark.png"

trap 'rm -rf "$STAGING_ROOT"' EXIT

cd "$ROOT_DIR"

mkdir -p "$ROOT_DIR/.build/cache/clang" "$ROOT_DIR/.build/cache/swiftpm"
mkdir -p "$ICON_BUILD_DIR"

SWIFTPM_HOME="$ROOT_DIR/.build/cache/swiftpm" \
CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/cache/clang" \
swift build -c release --disable-sandbox --scratch-path "$BUILD_DIR"

CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/cache/clang" \
swift "$ROOT_DIR/scripts/generate-icon.swift" "$ICONSET_DIR" "$ICON_PREVIEW" "$ICON_FILE"
xattr -cr "$ICONSET_DIR"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$EXECUTABLE" "$APP_DIR/Contents/MacOS/StudyTracker"
cp "$ICON_FILE" "$APP_DIR/Contents/Resources/StudyTrackerIcon.icns"
cp "$DARK_ICON" "$APP_DIR/Contents/Resources/StudyTrackerIcon-Dark.png"

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
    <string>com.wolfdog.StudyTrackerMac</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleIconFile</key>
    <string>StudyTrackerIcon</string>
    <key>CFBundleName</key>
    <string>Study Tracker</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
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
codesign --force --sign - --timestamp=none "$APP_DIR/Contents/MacOS/StudyTracker"
codesign --force --deep --sign - --timestamp=none "$APP_DIR"
xattr -cr "$APP_DIR"
codesign --verify --deep --strict --verbose=2 "$APP_DIR"

rm -f "$ARCHIVE_FILE"
COPYFILE_DISABLE=1 ditto -c -k --norsrc --noextattr --keepParent "$APP_DIR" "$ARCHIVE_FILE"
unzip -t "$ARCHIVE_FILE" >/dev/null

mkdir -p "$ROOT_DIR/dist"
rm -rf "$OUTPUT_APP_DIR"
rm -f "$OUTPUT_ARCHIVE_FILE"
COPYFILE_DISABLE=1 ditto --norsrc --noextattr "$APP_DIR" "$OUTPUT_APP_DIR"
cp "$ARCHIVE_FILE" "$OUTPUT_ARCHIVE_FILE"
xattr -cr "$OUTPUT_APP_DIR"

echo "Packaged: $OUTPUT_APP_DIR"
echo "Archive:  $OUTPUT_ARCHIVE_FILE"
