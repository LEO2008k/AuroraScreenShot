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
# rm -rf "$STAGING_DIR" # This line is replaced by the new cleanup
# rm -f "$DMG_NAME" # This line is removed

# CHANGED: Use a new directory to avoid permission issues
STAGING_DIR="dmg_build"
# Clean up previous build (ignore errors)
rm -rf "$STAGING_DIR" 2>/dev/null || true
mkdir -p "$STAGING_DIR"

# Copy App (Use rsync to exclude .DS_Store)
echo "Copying $APP_NAME.app to staging..."
rsync -a --exclude=".DS_Store" "$APP_NAME.app/" "$STAGING_DIR/$APP_NAME.app"

# Extra cleanup of .DS_Store just in case
find "$STAGING_DIR" -name ".DS_Store" -delete 2>/dev/null || true
# Create Link
echo "Creating Applications link..."
ln -s /Applications "$STAGING_DIR/Applications"

# Create DMG

# DMG Name is already set at the top: AuroraScreenshot_Installer.dmg
echo "Creating $DMG_NAME..."
hdiutil create -volname "AuroraScreenshot" -srcfolder "$STAGING_DIR" -ov -format UDZO "$DMG_NAME"
# rm -rf "dmg_staging"
echo "Cleaning up..."
# Try to clean up, but ignore errors if we can't
rm -rf "$STAGING_DIR" 2>/dev/null || true

echo "Applying App Icon to DMG file..."
# Only run if set_icon exists
if [ -f "set_icon.swift" ]; then
    swift set_icon.swift "icon.png" "$DMG_NAME" || echo "Icon apply failed but DMG is created."
fi

echo "✅ DMG Created successfully: $DMG_NAME"
open .
