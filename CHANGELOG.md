# Changelog

All notable changes to this project will be documented in this file.

## [2.0.34] - 2026-02-03

### Added

- **Aurora Branding**: Renamed app to "Aurora Screenshot" with gradient logo colors (Cyan → Green → Purple → Pink)
- **Aurora-themed UI**: Settings controls now use Aurora colors (Cyan toggle, Purple intensity slider, Teal glow size slider)
- **BETA Warning**: Added prominent BETA banner in AI settings tab
- **Bordered About Section**: Aurora gradient border around app info in Version tab
- **GitHub Integration**: Added README.md and .gitignore for public repository
- **Website Link**: Added clickable link to levko.kravchuk.net.ua in About section

### Changed

- **Aurora Glow Size**: Now configurable from 5-50px (default 15px) in Appearance settings
- **Separate AI Models**: Image analysis (llava) and Translation (llama3.1) use different models
- **Size Limits**: Separate configurable limits for Image (5MB) and Translation (500KB)

### Fixed

- UI consistency improvements across all settings tabs

## [2.0.6] - 2026-01-29

### Changed

- Standardized attribution headers to English in all source files.
- Fixed `Package.swift` syntax for `swift-tools-version`.

## [2.0.4] - 2026-01-29

### Added

- **Ollama Integration**: Analyze images using local LLM via `AIHelper`.
- **Ollama Settings**: Configure Host and Model in Preferences.
- **Manual Stamps**: Timestamp and Watermark buttons now manually toggle the effect.
- **Semantic Versioning**: Automated version bumping (Patch level) on build.

## [1.8.0] - 2026-01-28

### Added

- **Blur Background**: Apply blur to the inactive screenshot area.
- **New Tools**: Arrow and Line drawing tools.
- **Smart UI**: Toolbars avoid camera notch and position intelligently.
- **Share & Search**: AirDrop/Share Sheet and Google Image Search integration.
- **Preferences**: Launch at Login, AI API Key configuration.

## [1.5.0] - 2026-01-27

### Added

- **Redact Tool**: Draw filled rectangles to hide sensitive info.
- **Brush Size Shortcuts**: `[` and `]` keys to adjust size.

### Fixed

- Restored missing OCR button.
- Improved image flattening logic.

## [1.4.0] - 2026-01-26

### Changed

- **UI Overhaul**: Lightshot-style layout (Vertical tools, Horizontal actions).
- **UX**: Added Undo button and Quick Close (ESC).

## [1.3.0] - 2026-01-25

### Added

- **Preferences Window**: Custom Hotkey recording.
- **Dynamic Menu**: Menu item reflects current hotkey.

## [1.2.0] - 2026-01-24

### Added

- **OCR Editor**: Dedicated window for text editing.
- **Drawing Tools**: Pen tool with color picker.
- **Global Hotkey**: `Cmd+Shift+1` support.

## [1.0.0] - 2026-01-20

### Released

- Initial release with Menu Bar app, Screenshot capture, Drag selection, and basic OCR.
