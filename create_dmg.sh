#!/bin/bash
# This program was developed by Levko Kravchuk with the help of Vibe Coding

APP_NAME="AuroraScreenshot"
DMG_NAME="${APP_NAME}_Installer.dmg"
APP_PATH="${APP_NAME}.app"
STAGING_DIR="dmg_staging"

# Check if App exists
if [ ! -d "$APP_PATH" ]; then
    echo "Error: $APP_PATH not found. Please run ./bundle_app.sh first."
    exit 1
fi

echo "Preparing DMG staging area..."
# Clean up previous runs
rm -rf "$STAGING_DIR"
rm -f "$DMG_NAME"

# Create staging directory
mkdir -p "$STAGING_DIR"

# Copy App to staging
echo "Copying $APP_NAME.app to staging..."
cp -R "$APP_PATH" "$STAGING_DIR/"

# Create Symlink to Applications
echo "Creating Applications link..."
ln -s /Applications "$STAGING_DIR/Applications"

# Create DMG
echo "Creating $DMG_NAME..."
hdiutil create -volname "$APP_NAME Installer" -srcfolder "$STAGING_DIR" -ov -format UDZO "$DMG_NAME"

# Cleanup
echo "Cleaning up..."
rm -rf "$STAGING_DIR"

# Apply Icon to DMG
echo "Applying App Icon to DMG file..."
APP_ICON="$APP_PATH/Contents/Resources/AppIcon.icns"
if [ -f "$APP_ICON" ]; then
    swift set_icon.swift "$APP_ICON" "$DMG_NAME"
else
    echo "Warning: Icon not found at $APP_ICON"
fi

echo "✅ DMG Created successfully: $DMG_NAME"
open .
