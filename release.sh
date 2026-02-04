#!/bin/bash
set -e

# Load version
VERSION=$(cat version.txt)
echo "🚀 Preparing Release for Aurora Screenshot v${VERSION}..."

# 1. Build App and DMG
echo "📦 Building App and DMG..."
./bundle_app.sh

# Re-read version AFTER build (to match the app)
VERSION=$(cat version.txt)
echo "📦 App build complete. Version is now: $VERSION"

./create_dmg.sh

DMG_FILE="AuroraScreenshot_Installer.dmg"

if [ ! -f "$DMG_FILE" ]; then
    echo "❌ Error: DMG file not found!"
    exit 1
fi

echo "✅ Build complete. DMG is ready: ${DMG_FILE}"

# 2. Check for uncommitted changes
if [[ -n $(git status -s) ]]; then
    echo "⚠️  You have uncommitted changes. Please commit or stash them before releasing."
    git status -s
    # read -p "Continue anyway? (y/N) " confirm
    # if [[ "$confirm" != "y" ]]; then exit 1; fi
    # For automation, we will just warn but proceed if user runs this script explicitly
fi

# 3. Create Git Tag
TAG="v${VERSION}"
echo "🏷️  Checking tag ${TAG}..."

if git rev-parse "$TAG" >/dev/null 2>&1; then
    echo "⚠️  Tag ${TAG} already exists."
    read -p "Delete and recreate tag? (y/N) " confirm_tag
    if [[ "$confirm_tag" == "y" ]]; then
        git tag -d "$TAG"
        git push --delete origin "$TAG" 2>/dev/null || true
        echo "Deleted old tag."
    else
        echo "Using existing tag."
    fi
fi

# Create new tag if not currently on it
if ! git describe --exact-match --tags HEAD >/dev/null 2>&1; then
    echo "Creating new git tag: ${TAG}"
    git tag "$TAG"
    git push origin "$TAG"
else
    echo "Already on tag ${TAG}"
fi

# 4. Create GitHub Release
echo "⬆️  Uploading release to GitHub..."

# Check if release exists
if gh release view "$TAG" >/dev/null 2>&1; then
    echo "⚠️  Release ${TAG} already exists on GitHub."
    read -p "Overwrite artifacts? (y/N) " confirm_gh
    if [[ "$confirm_gh" == "y" ]]; then
        # Upload asset to existing release (clobber not supported directly, usually needs re-upload logic)
        # Easier to delete and recreate for this script
        gh release delete "$TAG" --yes
        echo "Deleted old release. Creating new one..."
    else
        echo "Aborted."
        exit 0
    fi
fi

# Extract changelog for this version (simple grep or just generic text)
NOTES="## Changes in ${TAG}\n\n- See CHANGELOG.md for details.\n- Automated build."

gh release create "$TAG" "$DMG_FILE" --title "Aurora Screen Shot ${TAG}" --notes "$NOTES"

echo "🎉 Release ${TAG} published successfully!"
echo "🔗 https://github.com/LEO2008k/AuroraScreenShot/releases/tag/${TAG}"
