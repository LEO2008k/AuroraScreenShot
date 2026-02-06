// This program was developed by Levko Kravchuk with the help of Vibe Coding
import Cocoa

class HotKeyManager {
    static let shared = HotKeyManager()
    
    private var monitor: Any?
    private var localMonitor: Any?
    
    var onScreenshotTriggered: (() -> Void)?
    var onOCRTriggered: (() -> Void)?
    var onRepeatTriggered: (() -> Void)?
    var onRunTriggered: (() -> Void)? // Legacy name? Keeping it or replacing with onCancelTriggered?
    var onCancelTriggered: (() -> Void)?
    var onTranslationTriggered: (() -> Void)? // New
    
    // Screenshot: Default Cmd+Shift+1
    private var screenshotKey: UInt16 = 18
    private var screenshotMods: NSEvent.ModifierFlags = [.command, .shift]
    
    // Quick OCR: Default Option+3
    private var ocrKey: UInt16 = 20
    private var ocrMods: NSEvent.ModifierFlags = [.option]
    
    // Repeat: Default Option+R
    private var repeatKey: UInt16 = 15
    private var repeatMods: NSEvent.ModifierFlags = [.option]
    
    // Translation: Default Option+T (Code 17 for 't')
    private var translationKey: UInt16 = 17
    private var translationMods: NSEvent.ModifierFlags = [.option]
    
    // Cancel: Default ESC (handled globally/locally)
    private var cancelKey: UInt16 = 53
    private var cancelMods: NSEvent.ModifierFlags = []
    
    // Settings: Default Option+M
    private var settingsKey: UInt16 = 46
    private var settingsMods: NSEvent.ModifierFlags = [.option]
    
    var onSettingsTriggered: (() -> Void)?
    
    func startMonitoring() {
        stopMonitoring()
        
        // Global
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            _ = self?.handleEvent(event)
        }
        
        // Local - consume event if handled to prevent character leaks (e.g., "!" in text fields)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            let handled = self.handleEvent(event)
            return handled ? nil : event  // Consume if hotkey matched
        }
    }
    
    func stopMonitoring() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        if let local = localMonitor {
            NSEvent.removeMonitor(local)
            self.localMonitor = nil
        }
    }
    
    private func handleEvent(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var handled = false
        
        // Check Screenshot
        if event.keyCode == screenshotKey && flags.contains(screenshotMods) && flags.subtracting(screenshotMods).isEmpty {
            onScreenshotTriggered?()
            handled = true
        }
        
        // Check OCR
        if event.keyCode == ocrKey && flags.contains(ocrMods) && flags.subtracting(ocrMods).isEmpty {
            onOCRTriggered?()
            handled = true
        }
        
        // Check Repeat
        if event.keyCode == repeatKey && flags.contains(repeatMods) && flags.subtracting(repeatMods).isEmpty {
            onRepeatTriggered?()
            handled = true
        }
        
        // Check Translation
        if event.keyCode == translationKey && flags.contains(translationMods) && flags.subtracting(translationMods).isEmpty {
            onTranslationTriggered?()
            handled = true
        }
        
        // Check Cancel (Only if mods match, usually empty for ESC)
        if event.keyCode == cancelKey && flags.contains(cancelMods) && flags.subtracting(cancelMods).isEmpty {
            onCancelTriggered?()
            handled = true
        }
        
        // Check Settings
        if event.keyCode == settingsKey && flags.contains(settingsMods) && flags.subtracting(settingsMods).isEmpty {
            onSettingsTriggered?()
            handled = true
        }
        
        return handled
    }
    
    func updateScreenshotHotKey(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        self.screenshotKey = keyCode
        self.screenshotMods = modifiers
    }
    
    func updateOCRHotKey(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        self.ocrKey = keyCode
        self.ocrMods = modifiers
    }
    
    func updateRepeatHotKey(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        self.repeatKey = keyCode
        self.repeatMods = modifiers
    }
    
    func updateCancelHotKey(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        self.cancelKey = keyCode
        self.cancelMods = modifiers
    }
    
    func updateTranslationHotKey(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        self.translationKey = keyCode
        self.translationMods = modifiers
    }
    
    func updateSettingsHotKey(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        self.settingsKey = keyCode
        self.settingsMods = modifiers
    }
}
