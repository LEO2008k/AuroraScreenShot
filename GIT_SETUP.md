# Git Setup Instructions

## Repository Initialization

```bash
cd /Users/levkokravchuk/Documents/Pet_proj/AuroraScreenShot

# Remove .build folder (if permission issues arise)
sudo rm -rf .build

# Initialize Git
git init

# Add all files
git add .

# Initial commit
git commit -m "Initial commit: Aurora Screen Shot v2.0.35

- Rebranding to 'Aurora Screen Shot'
- Aurora-themed UI with animated gradients
- Configurable glow size and effects
- Integrated local AI (Ollama) support
- Enhanced drawing tools and OCR"

# Add remote
git remote add origin https://github.com/LEO2008k/AuroraScreenShot.git

# Push to GitHub
git branch -M main
git push -u origin main
```

## Routine Updates

```bash
# After making changes
git add .
git commit -m "Describe your changes"
git push
```

## Creating a Release

```bash
# Create a version tag
git tag -a v2.0.35 -m "Aurora Screen Shot v2.0.35"
git push origin v2.0.35
```

Then on GitHub:

1. Go to **Releases**.
2. Click **"Create a new release"**.
3. Select tag `v2.0.35`.
4. Upload `AuroraScreenshot_Installer.dmg`.
5. Publish release.
