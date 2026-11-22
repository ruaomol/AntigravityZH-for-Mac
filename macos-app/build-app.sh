#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_NAME="AntigravityZH"
APP_BUNDLE="$PROJECT_ROOT/${APP_NAME}.app"
BUILD_TMP="$(mktemp -d "${TMPDIR:-/tmp}/agzh_build.XXXXXX")"

trap 'rm -rf "$BUILD_TMP"' EXIT

VERSION="1.6.1"
if [[ -f "$PROJECT_ROOT/VERSION" ]]; then
  VERSION="$(tr -d '[:space:]' < "$PROJECT_ROOT/VERSION")"
fi

SDK_PATH="$(xcrun --show-sdk-path)"
# CommandLineTools macOS 27+ SDK references Xcode-only SwiftUIMacros; use MacOSX26 SDK if present without Xcode.
if [[ "$SDK_PATH" == *"CommandLineTools"* ]] && [[ -d "/Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk" ]]; then
  SDK_PATH="/Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk"
fi
ARCH="$(uname -m)"
if [[ "$ARCH" == "arm64" ]]; then
  TARGET="arm64-apple-macosx14.0"
else
  TARGET="x86_64-apple-macosx14.0"
fi

echo "==> Building ${APP_NAME}.app (v${VERSION}, ${TARGET})"

# 1. Generate high-DPI macOS AppIcon.icns from AppIconSource.png
echo " -> Rendering macOS AppIcon..."
ICONSET_DIR="$BUILD_TMP/AppIcon.iconset"
swift -sdk "$SDK_PATH" "$SCRIPT_DIR/generate_icon.swift" "$SCRIPT_DIR/AppIconSource.png" "$ICONSET_DIR"
iconutil -c icns "$ICONSET_DIR" -o "$BUILD_TMP/AppIcon.icns"

# 2. Compile SwiftUI / AppKit native binary
echo " -> Compiling native SwiftUI application..."
swiftc \
  -O \
  -sdk "$SDK_PATH" \
  -target "$TARGET" \
  -framework AppKit \
  -framework SwiftUI \
  -framework CryptoKit \
  -framework QuartzCore \
  -framework UniformTypeIdentifiers \
  -o "$BUILD_TMP/$APP_NAME" \
  "$SCRIPT_DIR/Sources/Theme.swift" \
  "$SCRIPT_DIR/Sources/EnvironmentModels.swift" \
  "$SCRIPT_DIR/Sources/GeminiVisuals.swift" \
  "$SCRIPT_DIR/Sources/PatchController.swift" \
  "$SCRIPT_DIR/Sources/SettingsSheet.swift" \
  "$SCRIPT_DIR/Sources/MainView.swift" \
  "$SCRIPT_DIR/Sources/main.swift"

# 3. Assemble .app bundle
echo " -> Assembling ${APP_NAME}.app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources/Core"

cp "$BUILD_TMP/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "$BUILD_TMP/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

# Bundle self-contained Core engine inside Resources/Core so the .app works anywhere
cp "$PROJECT_ROOT/install.py" "$APP_BUNDLE/Contents/Resources/Core/"
cp "$PROJECT_ROOT/asar.py" "$APP_BUNDLE/Contents/Resources/Core/"
cp "$PROJECT_ROOT/VERSION" "$APP_BUNDLE/Contents/Resources/Core/"
cp -R "$PROJECT_ROOT/dicts" "$APP_BUNDLE/Contents/Resources/Core/dicts"

cat > "$APP_BUNDLE/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>zh_CN</string>
    <key>CFBundleDisplayName</key>
    <string>AntigravityZH</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.antigravityzh.mac</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>AntigravityZH</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
</dict>
</plist>
EOF

# 4. Ad-hoc sign & verify
echo " -> Signing bundle..."
codesign --force --deep --sign - --timestamp=none "$APP_BUNDLE"
codesign --verify --deep --strict "$APP_BUNDLE"

echo "==> Done: $APP_BUNDLE"
