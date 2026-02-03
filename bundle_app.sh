#!/bin/bash
# This program was developed by Levko Kravchuk with the help of Vibe Coding

APP_NAME="AuroraScreenshot"
BUILD_DIR=".build/arm64-apple-macosx/debug"
APP_DIR="$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

# Versioning Logic
# Read Semantic Version (e.g. 2.0.0)
if [ ! -f "version.txt" ]; then
    echo "1.0.0" > version.txt
fi
CURRENT_VER=$(cat version.txt)
# Split version into components
IFS='.' read -r -a PARTS <<< "$CURRENT_VER"
MAJOR="${PARTS[0]}"
MINOR="${PARTS[1]}"
PATCH="${PARTS[2]}"
# Increment Patch
PATCH=$((PATCH + 1))
SEM_VER="$MAJOR.$MINOR.$PATCH"
echo "$SEM_VER" > version.txt

# Read Build Number (e.g. 9)
if [ ! -f "build.txt" ]; then
    echo "1" > build.txt
fi
BUILD_NUM=$(cat build.txt)
BUILD_NUM=$((BUILD_NUM + 1))
echo $BUILD_NUM > build.txt

echo "Building Version: $SEM_VER (Build $BUILD_NUM)"

# Build the project first
echo "Building project..."
swift build

# Create directories
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Handle Icon
ICON_SOURCE="icon.png"
if [ -f "$ICON_SOURCE" ]; then
    echo "Generating App Icon..."
    ICONSET_DIR="OCRShot.iconset"
    mkdir -p "$ICONSET_DIR"
    
    # Generate standard sizes with explicit PNG format
    sips -z 16 16     "$ICON_SOURCE" --setProperty format png --out "$ICONSET_DIR/icon_16x16.png" > /dev/null
    sips -z 32 32     "$ICON_SOURCE" --setProperty format png --out "$ICONSET_DIR/icon_16x16@2x.png" > /dev/null
    sips -z 32 32     "$ICON_SOURCE" --setProperty format png --out "$ICONSET_DIR/icon_32x32.png" > /dev/null
    sips -z 64 64     "$ICON_SOURCE" --setProperty format png --out "$ICONSET_DIR/icon_32x32@2x.png" > /dev/null
    sips -z 128 128   "$ICON_SOURCE" --setProperty format png --out "$ICONSET_DIR/icon_128x128.png" > /dev/null
    sips -z 256 256   "$ICON_SOURCE" --setProperty format png --out "$ICONSET_DIR/icon_128x128@2x.png" > /dev/null
    sips -z 256 256   "$ICON_SOURCE" --setProperty format png --out "$ICONSET_DIR/icon_256x256.png" > /dev/null
    sips -z 512 512   "$ICON_SOURCE" --setProperty format png --out "$ICONSET_DIR/icon_256x256@2x.png" > /dev/null
    sips -z 512 512   "$ICON_SOURCE" --setProperty format png --out "$ICONSET_DIR/icon_512x512.png" > /dev/null
    sips -z 1024 1024 "$ICON_SOURCE" --setProperty format png --out "$ICONSET_DIR/icon_512x512@2x.png" > /dev/null
    
    # Debug: Check if files exist
    # ls -l "$ICONSET_DIR"
    
    iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/AppIcon.icns" || echo "Iconutil failed"
    rm -rf "$ICONSET_DIR"
    echo "Icon generated."
else
    echo "Warning: icon.png not found. App will have default icon."
fi

# Copy binary
echo "Copying binary..."
cp "$BUILD_DIR/$APP_NAME" "$MACOS_DIR/"

# Create Info.plist
echo "Creating Info.plist..."
cat > "$CONTENTS_DIR/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.levkokravchuk.$APP_NAME</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleShortVersionString</key>
    <string>$SEM_VER</string>
    <key>CFBundleVersion</key>
    <string>$BUILD_NUM</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSUIElement</key>
    <true/>
    <key>NSScreenCaptureUsageDescription</key>
    <string>We need access to record the screen to take screenshots.</string>
</dict>
</plist>
EOF

# Set permissions
chmod +x "$MACOS_DIR/$APP_NAME"

# Ad-hoc signing to persist permissions
echo "Signing app..."
codesign --force --deep --sign - "$APP_DIR"

# Force finder to refresh icon
touch "$APP_DIR"
touch "$APP_DIR/Contents/Info.plist"

echo "Done! $APP_NAME.app created."
echo "You can now move this to /Applications or run it directly."
