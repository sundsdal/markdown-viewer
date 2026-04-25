#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$PROJECT_DIR/build/release"
PRODUCT_PATH="$BUILD_DIR/Build/Products/Release/Markdown.app"
DEST="${DEST:-/Applications/Markdown.app}"

echo "→ Building Release…"
xcodebuild \
    -project "$PROJECT_DIR/Markdown.xcodeproj" \
    -scheme MarkdownViewer \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR" \
    clean build \
    | xcbeautify 2>/dev/null || \
xcodebuild \
    -project "$PROJECT_DIR/Markdown.xcodeproj" \
    -scheme MarkdownViewer \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR" \
    clean build \
    | tail -5

if [ ! -d "$PRODUCT_PATH" ]; then
    echo "✗ Build product not found at $PRODUCT_PATH" >&2
    exit 1
fi

if pgrep -f "$DEST/Contents/MacOS/" >/dev/null 2>&1; then
    echo "→ Quitting running Markdown.app…"
    osascript -e 'tell application "Markdown" to quit' 2>/dev/null || true
    for _ in 1 2 3 4 5; do
        pgrep -f "$DEST/Contents/MacOS/" >/dev/null 2>&1 || break
        sleep 0.4
    done
fi

echo "→ Installing to ${DEST}…"
rm -rf "$DEST"
cp -R "$PRODUCT_PATH" "$DEST"

codesign --verify --deep --strict "$DEST"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$DEST/Contents/Info.plist" 2>/dev/null || echo "?")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$DEST/Contents/Info.plist" 2>/dev/null || echo "?")"
echo "✓ Installed Markdown.app v$VERSION ($BUILD) → $DEST"
