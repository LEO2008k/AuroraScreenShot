// This program was developed by Levko Kravchuk with the help of Vibe Coding
import Foundation
import Cocoa
import SwiftUI

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    // Shortcuts
    @AppStorage("ShortcutKey") var shortcutKey: Int = 0x12 // '1' key
    @AppStorage("ShortcutModifiers") var shortcutModifiers: UInt = 0x100000 // Cmd
    
    @AppStorage("OCRShortcutKey") var ocrShortcutKey: Int = 0x13 // '2' key
    @AppStorage("OCRShortcutModifiers") var ocrShortcutModifiers: UInt = 0x100000 // Cmd
    
    // New: Repeat Last Selection Shortcut
    @AppStorage("RepeatShortcutKey") var repeatShortcutKey: Int = 0x0F // 'R' key (Default Cmd+R)
    @AppStorage("RepeatShortcutModifiers") var repeatShortcutModifiers: UInt = 0x100000 // Cmd
    
    // New: Cancel/Close Overlay Shortcut
    @AppStorage("CancelShortcutKey") var cancelShortcutKey: Int = 0x35 // 'Esc' key (53)
    @AppStorage("CancelShortcutModifiers") var cancelShortcutModifiers: UInt = 0 // No mod
    
    // Features
    @AppStorage("BlurBackground") var blurBackground = false
    @AppStorage("BlurAmount") var blurAmount = 5.0
    @AppStorage("AuroraGlowSize") var auroraGlowSize = 15.0 // Aurora glow coverage (5-50)
    @AppStorage("ShowTimestamp") var showTimestamp = false
    @AppStorage("TimestampFormat") var timestampFormat = "US"
    @AppStorage("ShowWatermark") var showWatermark = false
    @AppStorage("WatermarkText") var watermarkText = "Confidential"
    @AppStorage("WatermarkSize") var watermarkSize = 48.0
    @AppStorage("SaveDirectory") private var saveDirectoryPath: String = FileManager.default.homeDirectoryForCurrentUser.path
    
    // AI
    @AppStorage("AIPrompt") var aiPrompt: String = ""
    @AppStorage("AIApiKey") var aiApiKey: String = ""
    @AppStorage("EnableOllama") var enableOllama: Bool = false
    @AppStorage("OllamaHost") var ollamaHost: String = "http://localhost:11434"
    @AppStorage("OllamaModel") var ollamaModel: String = "llava"
    @AppStorage("OllamaTranslationModel") var ollamaTranslationModel: String = "llama3.1"
    
    // Proxy
    @AppStorage("ProxyServer") var proxyServer: String = ""
    
    // Size Limits (in KB)
    @AppStorage("MaxImageSizeKB") var maxImageSizeKB: Int = 5000 // 5MB for images
    @AppStorage("MaxTranslationSizeKB") var maxTranslationSizeKB: Int = 500 // 500KB for translation
    
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
    
    // Computed Shortcut wrapper
    var shortcut: Shortcut {
        get { Shortcut(keyCode: UInt16(shortcutKey), modifierFlags: shortcutModifiers) }
        set {
            shortcutKey = Int(newValue.keyCode)
            shortcutModifiers = newValue.modifierFlags
            objectWillChange.send()
        }
    }
    
    var ocrShortcut: Shortcut {
        get { Shortcut(keyCode: UInt16(ocrShortcutKey), modifierFlags: ocrShortcutModifiers) }
        set {
            ocrShortcutKey = Int(newValue.keyCode)
            ocrShortcutModifiers = newValue.modifierFlags
            objectWillChange.send()
        }
    }
    
    var repeatShortcut: Shortcut {
        get { Shortcut(keyCode: UInt16(repeatShortcutKey), modifierFlags: repeatShortcutModifiers) }
        set {
            repeatShortcutKey = Int(newValue.keyCode)
            repeatShortcutModifiers = newValue.modifierFlags
            objectWillChange.send()
        }
    }
    
    var cancelShortcut: Shortcut {
        get { Shortcut(keyCode: UInt16(cancelShortcutKey), modifierFlags: cancelShortcutModifiers) }
        set {
            cancelShortcutKey = Int(newValue.keyCode)
            cancelShortcutModifiers = newValue.modifierFlags
            objectWillChange.send()
        }
    }
    
    // Save Directory URL
    var saveDirectory: URL {
        get { URL(fileURLWithPath: saveDirectoryPath) }
        set {
            saveDirectoryPath = newValue.path
            objectWillChange.send()
        }
    }
    
    // Current Target Language for backwards compatibility if referenced directly
    var targetLanguage: String {
        get { defaultTargetLanguage }
        set { defaultTargetLanguage = newValue }
    }

    func promptForSaveDirectory() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.canCreateDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.begin { response in
            if response == .OK, let url = openPanel.url {
                 self.saveDirectory = url
            }
        }
    }
}
