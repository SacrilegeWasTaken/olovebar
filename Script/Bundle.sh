#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "Usage: $0 <executable-path> <output-app-path> [bundle-identifier]"
  exit 2
fi

EXECUTABLE_PATH="$1"
APP_PATH="$2"
BUNDLE_ID="${3:-com.sacrilege.olovebar}"
APP_NAME="OLoveBar"

if [ ! -f "$EXECUTABLE_PATH" ]; then
  echo "Executable not found: $EXECUTABLE_PATH"
  exit 2
fi

rm -rf "$APP_PATH"
mkdir -p "$APP_PATH/Contents/MacOS"
mkdir -p "$APP_PATH/Contents/Resources"

# Copy executable
cp "$EXECUTABLE_PATH" "$APP_PATH/Contents/MacOS/$APP_NAME"
chmod +x "$APP_PATH/Contents/MacOS/$APP_NAME"

# If a project icon exists, generate an .icns and place it into Resources
ICON_SOURCE="Resources/logo.png"


if [ -n "$ICON_SOURCE" ]; then
  echo "Found icon source: $ICON_SOURCE — generating AppIcon.icns"
  ICONSET_DIR="$APP_PATH/Contents/Resources/AppIcon.iconset"
  mkdir -p "$ICONSET_DIR"

  # generate required sizes
  sips -z 16 16     "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
  sips -z 32 32     "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
  sips -z 32 32     "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
  sips -z 64 64     "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
  sips -z 128 128   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
  sips -z 256 256   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
  sips -z 256 256   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
  sips -z 512 512   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
  sips -z 512 512   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
  sips -z 1024 1024 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512@2x.png" >/dev/null

  # Create .icns from iconset
  if command -v iconutil >/dev/null 2>&1; then
    iconutil -c icns "$ICONSET_DIR" -o "$APP_PATH/Contents/Resources/AppIcon.icns" >/dev/null 2>&1 || echo "iconutil failed"
  else
    echo "iconutil not found; skipping .icns generation"
  fi

  # copy a PNG version for status bar use
  sips -s format png "$ICON_SOURCE" --out "$APP_PATH/Contents/Resources/logo.png" >/dev/null || true

  # cleanup iconset
  rm -rf "$ICONSET_DIR"
fi

# Write Info.plist
cat > "$APP_PATH/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>LSBackgroundOnly</key>
    <false/>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
</dict>
</plist>
EOF

# Create PkgInfo
printf "APPL????" > "$APP_PATH/Contents/PkgInfo"

echo "Created app bundle at $APP_PATH"
exit 0
