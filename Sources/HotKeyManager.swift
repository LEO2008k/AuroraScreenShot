// This program was developed by Levko Kravchuk with the help of Vibe Coding
import Cocoa

class HotKeyManager {
    static let shared = HotKeyManager()
    
    private var monitor: Any?
    private var localMonitor: Any?
    
    var onScreenshotTriggered: (() -> Void)?
    var onOCRTriggered: (() -> Void)?
    var onRepeatTriggered: (() -> Void)?
    var onCancelTriggered: (() -> Void)?
    
    // Screenshot: Default Cmd+Shift+1
    private var screenshotKey: UInt16 = 18
    private var screenshotMods: NSEvent.ModifierFlags = [.command, .shift]
    
    // Quick OCR: Default Option+3
    private var ocrKey: UInt16 = 20
    private var ocrMods: NSEvent.ModifierFlags = [.option]
    
    // Repeat: Default Option+R
    private var repeatKey: UInt16 = 15
    private var repeatMods: NSEvent.ModifierFlags = [.option]
    
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
            self?.handleEvent(event)
        }
        
        // Local
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleEvent(event)
            // We return the event, unless we want to consume it? 
            // For Cancel (ESC), we might want to let it bubble if not used?
            // But usually we just monitor.
            return event
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
    
    private func handleEvent(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        
        // Check Screenshot
        if event.keyCode == screenshotKey && flags.contains(screenshotMods) && flags.subtracting(screenshotMods).isEmpty {
            onScreenshotTriggered?()
        }
        
        // Check OCR
        if event.keyCode == ocrKey && flags.contains(ocrMods) && flags.subtracting(ocrMods).isEmpty {
            onOCRTriggered?()
        }
        
        // Check Repeat
        if event.keyCode == repeatKey && flags.contains(repeatMods) && flags.subtracting(repeatMods).isEmpty {
            onRepeatTriggered?()
        }
        
        // Check Cancel (Only if mods match, usually empty for ESC)
        if event.keyCode == cancelKey && flags.contains(cancelMods) && flags.subtracting(cancelMods).isEmpty {
            onCancelTriggered?()
        }
        
        // Check Settings
        if event.keyCode == settingsKey && flags.contains(settingsMods) && flags.subtracting(settingsMods).isEmpty {
            onSettingsTriggered?()
        }
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
    
    func updateSettingsHotKey(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        self.settingsKey = keyCode
        self.settingsMods = modifiers
    }
}
