#!/bin/bash
set -euo pipefail

APP_NAME="HiDPI Scaler"
EXECUTABLE="HiDPIScaler"
BUNDLE_DIR="${APP_NAME}.app"

echo "=== Building HiDPI Scaler ==="

# Step 1: Build with SPM
echo "[1/4] Compiling..."
swift build -c release 2>&1

# Find the built binary
BINARY=".build/release/${EXECUTABLE}"
if [ ! -f "$BINARY" ]; then
    # Try arm64 path
    BINARY=".build/arm64-apple-macosx/release/${EXECUTABLE}"
fi

if [ ! -f "$BINARY" ]; then
    echo "ERROR: Built binary not found"
    exit 1
fi

echo "[2/4] Creating app bundle..."

# Step 2: Create .app bundle structure
rm -rf "${BUNDLE_DIR}"
mkdir -p "${BUNDLE_DIR}/Contents/MacOS"
mkdir -p "${BUNDLE_DIR}/Contents/Resources"

# Copy binary
cp "$BINARY" "${BUNDLE_DIR}/Contents/MacOS/${EXECUTABLE}"

# Copy Info.plist
cp "Resources/Info.plist" "${BUNDLE_DIR}/Contents/"

# Copy app icon
cp "Resources/AppIcon.icns" "${BUNDLE_DIR}/Contents/Resources/"

# Create PkgInfo
echo -n "APPL????" > "${BUNDLE_DIR}/Contents/PkgInfo"

echo "[3/4] Code signing (ad-hoc)..."

# Step 3: Ad-hoc code sign
codesign --force --sign - "${BUNDLE_DIR}/Contents/MacOS/${EXECUTABLE}" 2>/dev/null || true
codesign --force --sign - "${BUNDLE_DIR}" 2>/dev/null || true

echo "[4/4] Done!"
echo ""
echo "App bundle created: ${BUNDLE_DIR}"
echo ""
echo "To run:"
echo "  open \"${BUNDLE_DIR}\""
echo ""
echo "To install to Applications:"
echo "  cp -r \"${BUNDLE_DIR}\" /Applications/"
echo ""
echo "The app will appear in your menu bar (no dock icon)."
echo "Click the sparkles icon to configure HiDPI scaling."
