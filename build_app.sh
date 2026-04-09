#!/bin/bash
# RecordShot build script
# Usage:
#   ./build_app.sh           # release build
#   ./build_app.sh debug     # debug build

set -e

APP_NAME="RecordShot"
BUILD_CONFIG="${1:-release}"
BINARY_PATH=".build/${BUILD_CONFIG}/${APP_NAME}"
APP_DIR="${APP_NAME}.app"

echo "→ Building (${BUILD_CONFIG})..."
swift build -c "${BUILD_CONFIG}"

[ -f "${BINARY_PATH}" ] || { echo "Error: binary not found at ${BINARY_PATH}"; exit 1; }

echo "→ Creating app bundle..."
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

# Binary
cp "${BINARY_PATH}" "${APP_DIR}/Contents/MacOS/${APP_NAME}"

# Info.plist
cp "RecordShot/Info.plist" "${APP_DIR}/Contents/Info.plist"

# App icon — build ICNS from the PNG files already in Assets.xcassets
echo "→ Creating app icon..."
ICONSET="RecordShot.iconset"
rm -rf "${ICONSET}"
mkdir "${ICONSET}"
cp RecordShot/Assets.xcassets/AppIcon.appiconset/icon_*.png "${ICONSET}/"
iconutil -c icns "${ICONSET}" -o "${APP_DIR}/Contents/Resources/AppIcon.icns"
rm -rf "${ICONSET}"

# Localizations
echo "→ Copying localizations..."
cp -r "RecordShot/en.lproj" "${APP_DIR}/Contents/Resources/"
cp -r "RecordShot/ko.lproj" "${APP_DIR}/Contents/Resources/"

# Ad-hoc sign with entitlements (required for screen capture permission)
echo "→ Signing..."
codesign --force --sign - \
    --entitlements "RecordShot/RecordShot.entitlements" \
    "${APP_DIR}"

echo ""
echo "✓ ${APP_DIR} ready"
echo "  Run:     open ${APP_DIR}"
echo "  Restart: pkill -x ${APP_NAME}; sleep 1; open ${APP_DIR}"
echo ""
echo "  If screen capture permission is lost after rebuild:"
echo "  tccutil reset ScreenCapture com.recordshot.app"
