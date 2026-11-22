#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_NAME="AntigravityZH"
APP_BUNDLE="$PROJECT_ROOT/${APP_NAME}.app"
DIST_DIR="$PROJECT_ROOT/dist"

VERSION="1.6.1"
if [[ -f "$PROJECT_ROOT/VERSION" ]]; then
  VERSION="$(tr -d '[:space:]' < "$PROJECT_ROOT/VERSION")"
fi

DMG_NAME="AntigravityZH-for-Mac-v${VERSION}.dmg"
DMG_PATH="$DIST_DIR/$DMG_NAME"
STAGE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/agzh_dmg.XXXXXX")"
trap 'rm -rf "$STAGE_DIR"' EXIT

# 1. Ensure fresh signed .app bundle
"$SCRIPT_DIR/build-app.sh"

# 2. Prepare clean drag-to-Applications staging folder
mkdir -p "$DIST_DIR"
cp -R "$APP_BUNDLE" "$STAGE_DIR/${APP_NAME}.app"
ln -s /Applications "$STAGE_DIR/Applications"

# 3. Create compressed UDZO DMG
echo "==> Packaging $DMG_NAME ..."
rm -f "$DMG_PATH" "${DMG_PATH}.sha256"
hdiutil create \
  -volname "AntigravityZH" \
  -srcfolder "$STAGE_DIR" \
  -ov \
  -format UDZO \
  -imagekey zlib-level=9 \
  "$DMG_PATH"

# 4. Verify DMG integrity & generate SHA-256 checksum
echo " -> Verifying DMG..."
hdiutil verify "$DMG_PATH"
(cd "$DIST_DIR" && shasum -a 256 "$DMG_NAME" > "${DMG_NAME}.sha256")

echo "==> Done: $DMG_PATH"
cat "${DMG_PATH}.sha256"
