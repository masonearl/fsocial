#!/bin/bash

# Social Hub - Release Build Script
# This script builds, signs, notarizes, packages, and publishes the app
# Builds Universal Binary for both Intel and Apple Silicon Macs

set -e

PROJECT_DIR="/Users/masdawg/Desktop/Brain/Mason/1. Projects/1. Code/1. Apps/fsocial/fsocial"
APP_NAME="fsocial"
DMG_NAME="fsocial"
DEVELOPER_ID="Developer ID Application: Mason Earl (3FXGJUET7Y)"
NOTARY_PROFILE="fsocial-notary"
GITHUB_REPO="masonearl/fsocial"

cd "$PROJECT_DIR"

# Get version - auto-increment patch version from last release
LAST_TAG=$(gh release list --repo "$GITHUB_REPO" --limit 1 --json tagName -q '.[0].tagName' 2>/dev/null || echo "v0.0.0")
LAST_VERSION="${LAST_TAG#v}"

if [ -z "$LAST_VERSION" ] || [ "$LAST_VERSION" = "null" ]; then
    LAST_VERSION="0.0.0"
fi

# Parse version components
IFS='.' read -r MAJOR MINOR PATCH <<< "$LAST_VERSION"
PATCH=$((PATCH + 1))
NEW_VERSION="$MAJOR.$MINOR.$PATCH"

echo "============================================"
echo "Building fsocial v$NEW_VERSION"
echo "============================================"
echo ""
echo "Note: This script passes MARKETING_VERSION to xcodebuild for the GitHub DMG"
echo "only. Mac App Store archives must use MARKETING_VERSION / CURRENT_PROJECT_VERSION"
echo "from project.pbxproj (1.1.0 / 2 for the next MAS upload)."
echo ""

echo "[1/7] Building Universal Binary (Intel + Apple Silicon)..."
xcodebuild -project "$APP_NAME.xcodeproj" -scheme "$APP_NAME" -configuration Release clean build \
    ARCHS="x86_64 arm64" \
    ONLY_ACTIVE_ARCH=NO \
    MARKETING_VERSION="$NEW_VERSION" \
    2>&1 | grep -E "(BUILD|error:|warning:)" || true

APP_PATH="/Users/masdawg/Library/Developer/Xcode/DerivedData/fsocial-axyvdsothnptwbhfditbzvrlwnsd/Build/Products/Release/$APP_NAME.app"

# Verify it's Universal
echo ""
echo "Verifying Universal Binary..."
file "$APP_PATH/Contents/MacOS/$APP_NAME"

echo ""
echo "[2/7] Signing with Developer ID..."
codesign --force --deep --options runtime --sign "$DEVELOPER_ID" "$APP_PATH"

echo ""
echo "[3/7] Creating zip for notarization..."
ZIP_PATH="/tmp/$APP_NAME-notarize.zip"
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

echo ""
echo "[4/7] Submitting for notarization (this may take a minute)..."
xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$NOTARY_PROFILE" --wait

echo ""
echo "[5/7] Stapling notarization ticket..."
xcrun stapler staple "$APP_PATH"

echo ""
echo "[6/7] Creating DMG..."
DMG_DIR="$PROJECT_DIR/dist"
DMG_PATH="$DMG_DIR/$DMG_NAME.dmg"
mkdir -p "$DMG_DIR"
rm -f "$DMG_PATH"

TEMP_DMG_DIR=$(mktemp -d)
cp -R "$APP_PATH" "$TEMP_DMG_DIR/"
ln -s /Applications "$TEMP_DMG_DIR/Applications"
hdiutil create -volname "fsocial" -srcfolder "$TEMP_DMG_DIR" -ov -format UDZO "$DMG_PATH"
rm -rf "$TEMP_DMG_DIR"
rm -f "$ZIP_PATH"

echo ""
echo "[7/7] Publishing to GitHub..."
gh release create "v$NEW_VERSION" \
  --repo "$GITHUB_REPO" \
  --title "Social Hub v$NEW_VERSION" \
  --notes "Release v$NEW_VERSION - Universal Binary (Intel + Apple Silicon)" \
  "$DMG_PATH"

echo ""
echo "============================================"
echo "BUILD AND PUBLISH COMPLETE"
echo "============================================"
echo ""
echo "Version: v$NEW_VERSION"
echo "DMG: $DMG_PATH"
echo "Release: https://github.com/$GITHUB_REPO/releases/tag/v$NEW_VERSION"
echo ""
echo "Direct download URL:"
echo "https://github.com/$GITHUB_REPO/releases/latest/download/$DMG_NAME.dmg"
