import Foundation
import Cocoa

// Capture quality levels
enum CaptureQuality: String, Codable, CaseIterable {
    case maximum = "maximum"   // 2x Retina, high memory
    case medium = "medium"     // 1x nominal, recommended
    case minimum = "minimum"   // Downscaled, low memory
    
    var displayName: String {
        switch self {
        case .maximum: return "Maximum (2x Retina)"
        case .medium: return "Medium (1x)"
        case .minimum: return "Minimum (Downscaled)"
        }
    }
    
    var memoryEstimate: String {
        switch self {
        case .maximum: return "Max Quality (HDR, ~2.5GB limit)"
        case .medium: return "Balanced (~1GB limit)"
        case .minimum: return "Low Memory (~300MB limit)"
        }
    }
    
    var maxMemoryBytes: Int {
        switch self {
        case .maximum: return 2500 * 1024 * 1024 // 2.5 GB
        case .medium: return 1024 * 1024 * 1024  // 1 GB
        case .minimum: return 300 * 1024 * 1024  // 300 MB
        }
    }
}

class SettingsManager {
    static let shared = SettingsManager()
    
    private let kSaveDirectory = "SaveDirectory"
    private let kShortcut = "AppShortcut"
    
    var saveDirectory: URL {
        get {
            if let path = UserDefaults.standard.string(forKey: kSaveDirectory) {
                return URL(fileURLWithPath: path)
            }
            let paths = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask)
            return paths.first ?? URL(fileURLWithPath: "/tmp")
        }
        set {
            UserDefaults.standard.set(newValue.path, forKey: kSaveDirectory)
        }
    }
    
    private let kBlurBackground = "BlurBackground"
    private let kBlurAmount = "BlurAmount"
    private let kUIScale = "UIScale"
    private let kAIApiKey = "AIApiKey"
    private let kAIPrompt = "AIPrompt"
    private let kLaunchAtLogin = "LaunchAtLogin"
    
    var blurBackground: Bool {
        get { UserDefaults.standard.bool(forKey: kBlurBackground) }
        set { UserDefaults.standard.set(newValue, forKey: kBlurBackground) }
    }
    
    var uiScale: Double {
        get { 
            let val = UserDefaults.standard.double(forKey: kUIScale)
            return val == 0 ? 1.0 : val
        }
        set { UserDefaults.standard.set(newValue, forKey: kUIScale) }
    }
    
    var blurAmount: Double {
        get { 
            let val = UserDefaults.standard.double(forKey: kBlurAmount)
            return val == 0 ? 5.0 : val
        }
        set { UserDefaults.standard.set(newValue, forKey: kBlurAmount) }
    }
    
    var aiApiKey: String {
        get { UserDefaults.standard.string(forKey: kAIApiKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: kAIApiKey) }
    }
    
    var aiPrompt: String {
        get { UserDefaults.standard.string(forKey: kAIPrompt) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: kAIPrompt) }
    }
    
    var launchAtLogin: Bool {
        get { UserDefaults.standard.bool(forKey: kLaunchAtLogin) }
        set { 
            UserDefaults.standard.set(newValue, forKey: kLaunchAtLogin)
            // TODO: Call helper to register/unregister login item
        }
    }

    private let kTargetLanguage = "TargetLanguage"
    private let kOCRShortcut = "OCRShortcut"
    
    // Timestamp & Watermark Keys
    private let kShowTimestamp = "ShowTimestamp"
    private let kTimestampFormat = "TimestampFormat"
    private let kShowWatermark = "ShowWatermark"
    private let kWatermarkText = "WatermarkText"
    private let kWatermarkSize = "WatermarkSize"
    
    var targetLanguage: String {
        get { UserDefaults.standard.string(forKey: kTargetLanguage) ?? "English" }
        set { UserDefaults.standard.set(newValue, forKey: kTargetLanguage) }
    }
    
    // Aurora Settings
    private let kEnableAurora = "EnableAurora"
    private let kAuroraIntensity = "AuroraIntensity"
    
    var enableAurora: Bool {
        get { UserDefaults.standard.bool(forKey: kEnableAurora) }
        set { UserDefaults.standard.set(newValue, forKey: kEnableAurora) }
    }
    
    var auroraIntensity: Double {
        get { 
             let val = UserDefaults.standard.double(forKey: kAuroraIntensity)
             return val == 0 ? 1.0 : val
        }
        set { UserDefaults.standard.set(newValue, forKey: kAuroraIntensity) }
    }
    
    // MARK: - HotKey Helpers
    func getHotKey(key: String) -> (Int, UInt, Bool) {
        let code = UserDefaults.standard.integer(forKey: "\(key)_keyCode")
        let mods = UserDefaults.standard.integer(forKey: "\(key)_modifiers")
        let enabled = UserDefaults.standard.object(forKey: "\(key)_enabled") as? Bool ?? true
        // Default codes if not set
        if code == 0 {
            if key == "hotkey" { return (18, NSEvent.ModifierFlags([.command, .shift]).rawValue, true) } // Cmd+Shift+1
            if key == "globalHotkey" { return (19, NSEvent.ModifierFlags([.command, .shift]).rawValue, true) } // Cmd+Shift+2 (Legacy?) or Cmd+Shift+2
            // Actually globalHotkey usually refers to the main screenshot one.
            // Let's stick to reading values.
        }
        return (code, UInt(mods), enabled)
    }

    func saveHotKey(key: String, keyCode: Int, modifiers: UInt, enable: Bool) {
        UserDefaults.standard.set(keyCode, forKey: "\(key)_keyCode")
        UserDefaults.standard.set(modifiers, forKey: "\(key)_modifiers")
        UserDefaults.standard.set(enable, forKey: "\(key)_enabled")
    }

    // Specialized HotKey Getters
    var screenshotHotKey:  (Int, UInt, Bool) { getHotKey(key: "hotkey") }
    var globalHotKey:      (Int, UInt, Bool) { getHotKey(key: "globalHotkey") }
    var translationHotKey: (Int, UInt, Bool) { getHotKey(key: "translationHotkey") }
    
    // Timestamp Settings
    var showTimestamp: Bool {
        get { UserDefaults.standard.bool(forKey: kShowTimestamp) }
        set { UserDefaults.standard.set(newValue, forKey: kShowTimestamp) }
    }
    
    var timestampFormat: String {
        get { UserDefaults.standard.string(forKey: kTimestampFormat) ?? "US" }
        set { UserDefaults.standard.set(newValue, forKey: kTimestampFormat) }
    }
    
    // Watermark Settings
    var showWatermark: Bool {
        get { UserDefaults.standard.bool(forKey: kShowWatermark) }
        set { UserDefaults.standard.set(newValue, forKey: kShowWatermark) }
    }
    
    var watermarkText: String {
        get { UserDefaults.standard.string(forKey: kWatermarkText) ?? "Confidential" }
        set { UserDefaults.standard.set(newValue, forKey: kWatermarkText) }
    }
    
    var watermarkSize: Double {
        get { 
            let val = UserDefaults.standard.double(forKey: kWatermarkSize)
            return val == 0 ? 30.0 : val
        }
        set { UserDefaults.standard.set(newValue, forKey: kWatermarkSize) }
    }
    
    var shortcut: Shortcut {
        get {
            if let data = UserDefaults.standard.data(forKey: kShortcut),
               let saved = try? JSONDecoder().decode(Shortcut.self, from: data) {
                return saved
            }
            return Shortcut.defaultShortcut
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: kShortcut)
            }
        }
    }
    
    var ocrShortcut: Shortcut {
        get {
            if let data = UserDefaults.standard.data(forKey: kOCRShortcut),
               let saved = try? JSONDecoder().decode(Shortcut.self, from: data) {
                return saved
            }
            // Default: Option+3 (or user preferred)
            return Shortcut(keyCode: 20, modifierFlags: 524288) // Key 20='3', Opt (524288)
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: kOCRShortcut)
            }
        }
    }
    
    private let kRepeatShortcut = "RepeatShortcut"
    private let kCancelShortcut = "CancelShortcut"
    private let kSettingsShortcut = "SettingsShortcut"
    
    var repeatShortcut: Shortcut {
        get {
            if let data = UserDefaults.standard.data(forKey: kRepeatShortcut),
               let saved = try? JSONDecoder().decode(Shortcut.self, from: data) {
                return saved
            }
            return Shortcut(keyCode: 15, modifierFlags: 524288) // Default: Option+R (Key 15)
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: kRepeatShortcut)
            }
        }
    }
    
    var settingsShortcut: Shortcut {
        get {
            if let data = UserDefaults.standard.data(forKey: kSettingsShortcut),
               let saved = try? JSONDecoder().decode(Shortcut.self, from: data) {
                return saved
            }
            return Shortcut(keyCode: 46, modifierFlags: 524288) // Default: Option+M (Key 46)
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: kSettingsShortcut)
            }
        }
    }
    
    var cancelShortcut: Shortcut {
        get {
            if let data = UserDefaults.standard.data(forKey: kCancelShortcut),
               let saved = try? JSONDecoder().decode(Shortcut.self, from: data) {
                return saved
            }
            return Shortcut(keyCode: 53, modifierFlags: 0) // Default: ESC (Key 53)
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: kCancelShortcut)
            }
        }
    }
    
    // Updates Settings
    private let kUpdateFrequency = "UpdateFrequency"
    private let kProxyServer = "ProxyServer"
    private let kRepositoryURL = "RepositoryURL"
    
    var updateFrequency: String {
        get { UserDefaults.standard.string(forKey: kUpdateFrequency) ?? "Weekly" }
        set { UserDefaults.standard.set(newValue, forKey: kUpdateFrequency) }
    }
    
    var proxyServer: String {
        get { UserDefaults.standard.string(forKey: kProxyServer) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: kProxyServer) }
    }
    
    var repositoryURL: String {
        get { UserDefaults.standard.string(forKey: kRepositoryURL) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: kRepositoryURL) }
    }
    
    // Ollama Keys
    private let kEnableOllama = "EnableOllama"
    private let kOllamaHost = "OllamaHost"
    private let kOllamaModel = "OllamaModel"

    var enableOllama: Bool {
        get { UserDefaults.standard.bool(forKey: kEnableOllama) }
        set { UserDefaults.standard.set(newValue, forKey: kEnableOllama) }
    }
    
    var ollamaHost: String {
        get { UserDefaults.standard.string(forKey: kOllamaHost) ?? "http://127.0.0.1:11434" }
        set { UserDefaults.standard.set(newValue, forKey: kOllamaHost) }
    }
    
    var ollamaModel: String {
        get { UserDefaults.standard.string(forKey: kOllamaModel) ?? "llava" }
        set { UserDefaults.standard.set(newValue, forKey: kOllamaModel) }
    }
    
    // Translation Model (separate from image analysis model)
    private let kOllamaTranslationModel = "OllamaTranslationModel"
    
    var ollamaTranslationModel: String {
        get { UserDefaults.standard.string(forKey: kOllamaTranslationModel) ?? "llama3.1" }
        set { UserDefaults.standard.set(newValue, forKey: kOllamaTranslationModel) }
    }

    private let kShowTranslateButton = "ShowTranslateButton"
    var showTranslateButton: Bool {
        get { UserDefaults.standard.object(forKey: kShowTranslateButton) as? Bool ?? true } // Default true
        set { UserDefaults.standard.set(newValue, forKey: kShowTranslateButton) }
    }
    
    // Size Limits
    private let kMaxImageSizeKB = "MaxImageSizeKB"
    private let kMaxTranslationSizeKB = "MaxTranslationSizeKB"
    
    var maxImageSizeKB: Int {
        get { 
            let val = UserDefaults.standard.integer(forKey: kMaxImageSizeKB)
            return val == 0 ? 5000 : val // Default 5MB
        }
        set { UserDefaults.standard.set(newValue, forKey: kMaxImageSizeKB) }
    }
    
    var maxTranslationSizeKB: Int {
        get { 
            let val = UserDefaults.standard.integer(forKey: kMaxTranslationSizeKB)
            return val == 0 ? 500 : val // Default 500KB
        }
        set { UserDefaults.standard.set(newValue, forKey: kMaxTranslationSizeKB) }
    }
    
    // Aurora Glow Size
    private let kAuroraGlowSize = "AuroraGlowSize"
    
    var auroraGlowSize: Double {
        get { 
            let val = UserDefaults.standard.double(forKey: kAuroraGlowSize)
            return val == 0 ? 15.0 : val // Default 15px
        }
        set { UserDefaults.standard.set(newValue, forKey: kAuroraGlowSize) }
    }
    
    // Translation Settings
    private let kTranslationLanguages = "TranslationLanguages"
    private let kDefaultTargetLanguage = "DefaultTargetLanguage"
    
    var translationLanguages: [String] {
        get {
            if let array = UserDefaults.standard.stringArray(forKey: kTranslationLanguages) {
                return array
            }
            return ["Ukrainian", "English", "Spanish", "German", "French", "Polish", "Italian", "Chinese"]
        }
        set {
            UserDefaults.standard.set(newValue, forKey: kTranslationLanguages)
        }
    }
    
    var defaultTargetLanguage: String {
        get { UserDefaults.standard.string(forKey: kDefaultTargetLanguage) ?? "Ukrainian" }
        set { UserDefaults.standard.set(newValue, forKey: kDefaultTargetLanguage) }
    }
    
    
    // Capture Quality (replaces old downscaleRetina)
    private let kCaptureQuality = "CaptureQuality"
    var captureQuality: String {
        get { 
            // Migration: if new setting doesn't exist but old one does
            if UserDefaults.standard.object(forKey: kCaptureQuality) == nil {
                let oldDownscale = UserDefaults.standard.bool(forKey: "DownscaleRetina")
                return oldDownscale ? CaptureQuality.medium.rawValue : CaptureQuality.maximum.rawValue
            }
            return UserDefaults.standard.string(forKey: kCaptureQuality) ?? CaptureQuality.medium.rawValue
        }
        set { UserDefaults.standard.set(newValue, forKey: kCaptureQuality) }
    }
    
    var quality: CaptureQuality {
        get { CaptureQuality(rawValue: captureQuality) ?? .medium }
        set { captureQuality = newValue.rawValue }
    }
    
    // Backward compatibility: map quality to old downscaleRetina for existing code
    var downscaleRetina: Bool {
        get { quality != .maximum }
        set { quality = newValue ? .medium : .maximum }
    }
    
    // Warning suppression for maximum quality
    private let kSuppressMaxQualityWarning = "SuppressMaxQualityWarning"
    var suppressMaxQualityWarning: Bool {
        get { UserDefaults.standard.bool(forKey: kSuppressMaxQualityWarning) }
        set { UserDefaults.standard.set(newValue, forKey: kSuppressMaxQualityWarning) }
    }
    
    // RAM Detection
    static func getTotalRAMGB() -> Int {
        var size: UInt64 = 0
        var len = MemoryLayout.size(ofValue: size)
        sysctlbyname("hw.memsize", &size, &len, nil, 0)
        return Int(size / (1024 * 1024 * 1024))
    }
    
    static func canUseMaximumQuality() -> Bool {
        return getTotalRAMGB() >= 12
    }

    
    // Auto Restart
    private let kAutoRestartAfterUpdate = "AutoRestartAfterUpdate"
    var autoRestartAfterUpdate: Bool {
        get { 
            if UserDefaults.standard.object(forKey: kAutoRestartAfterUpdate) == nil {
                return true // Default true
            }
            return UserDefaults.standard.bool(forKey: kAutoRestartAfterUpdate)
        }
        set { UserDefaults.standard.set(newValue, forKey: kAutoRestartAfterUpdate) }
    }
    
    // Auto Check Updates
    private let kAutoCheckUpdates = "AutoCheckUpdates"
    var autoCheckUpdates: Bool {
        get {
            if UserDefaults.standard.object(forKey: kAutoCheckUpdates) == nil {
                return true // Default true
            }
            return UserDefaults.standard.bool(forKey: kAutoCheckUpdates)
        }
        set { UserDefaults.standard.set(newValue, forKey: kAutoCheckUpdates) }
    }
    
    // History Settings
    private let kSaveHistory = "SaveHistory"
    private let kHistoryRetentionHours = "HistoryRetentionHours"
    
    var saveHistory: Bool {
        get { UserDefaults.standard.bool(forKey: kSaveHistory) }
        set { UserDefaults.standard.set(newValue, forKey: kSaveHistory) }
    }
    
    var historyRetentionHours: Int {
        get { 
            let val = UserDefaults.standard.integer(forKey: kHistoryRetentionHours)
            return val == 0 ? 48 : val // Default 48 hours
        }
        set { UserDefaults.standard.set(newValue, forKey: kHistoryRetentionHours) }
    }
    
    // OCR Editor Appearance
    private let kOCRFontSize = "OCRFontSize"
    private let kOCREditorBgMode = "OCREditorBgMode" // "System", "Dark", "Light", "Custom"
    private let kOCREditorCustomColor = "OCREditorCustomColor"

    var ocrFontSize: Double {
        get { 
            let val = UserDefaults.standard.double(forKey: kOCRFontSize)
            return val == 0 ? 13.0 : val
        }
        set { UserDefaults.standard.set(newValue, forKey: kOCRFontSize) }
    }
    
    var ocrEditorBgMode: String {
        get { UserDefaults.standard.string(forKey: kOCREditorBgMode) ?? "Dark" }
        set { UserDefaults.standard.set(newValue, forKey: kOCREditorBgMode) }
    }
    
    var ocrEditorCustomColor: String {
        get { UserDefaults.standard.string(forKey: kOCREditorCustomColor) ?? "#1E1E1E" }
        set { UserDefaults.standard.set(newValue, forKey: kOCREditorCustomColor) }
    }
    
    func promptForSaveDirectory() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.canCreateDirectories = true
        openPanel.prompt = "Select"
        openPanel.title = "Select Screenshot Save Location"
        
        openPanel.begin { response in
            if response == .OK, let url = openPanel.url {
                self.saveDirectory = url
            }
        }
    }
}
