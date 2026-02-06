// This program was developed by Levko Kravchuk with the help of Vibe Coding
import Cocoa
import Carbon.HIToolbox

class HotKeyManager {
    static let shared = HotKeyManager()
    
    // Callbacks
    var onScreenshotTriggered: (() -> Void)?
    var onOCRTriggered: (() -> Void)?
    var onRepeatTriggered: (() -> Void)?
    var onCancelTriggered: (() -> Void)?
    var onTranslationTriggered: (() -> Void)?
    var onSettingsTriggered: (() -> Void)?
    
    // Carbon hotkey storage
    private var registeredHotKeys: [EventHotKeyRef?] = []
    private var eventHandler: EventHandlerRef?
    
    // Hotkey settings (defaults)
    // Screenshot: Cmd+Shift+1
    private var screenshotKey: UInt16 = 18
    private var screenshotMods: NSEvent.ModifierFlags = [.command, .shift]
    
    // Quick OCR: Option+3
    private var ocrKey: UInt16 = 20
    private var ocrMods: NSEvent.ModifierFlags = [.option]
    
    // Repeat: Option+R
    private var repeatKey: UInt16 = 15
    private var repeatMods: NSEvent.ModifierFlags = [.option]
    
    // Translation: Option+T
    private var translationKey: UInt16 = 17
    private var translationMods: NSEvent.ModifierFlags = [.option]
    
    // Settings: Option+M
    private var settingsKey: UInt16 = 46
    private var settingsMods: NSEvent.ModifierFlags = [.option]
    
    // Cancel: ESC (not registered as global - handled in OverlayController)
    private var cancelKey: UInt16 = 53
    private var cancelMods: NSEvent.ModifierFlags = []
    
    // Hotkey IDs
    private enum HotKeyID: UInt32 {
        case screenshot = 1
        case ocr = 2
        case translation = 3
        case repeatAction = 4
        case settings = 5
    }
    
    func startMonitoring() {
        stopMonitoring()
        
        // Install Carbon event handler
        installCarbonEventHandler()
        
        // Register all global hotkeys
        registerHotKey(id: .screenshot, keyCode: screenshotKey, modifiers: screenshotMods)
        registerHotKey(id: .ocr, keyCode: ocrKey, modifiers: ocrMods)
        registerHotKey(id: .translation, keyCode: translationKey, modifiers: translationMods)
        registerHotKey(id: .repeatAction, keyCode: repeatKey, modifiers: repeatMods)
        registerHotKey(id: .settings, keyCode: settingsKey, modifiers: settingsMods)
    }
    
    func stopMonitoring() {
        // Unregister all hotkeys
        for hotKeyRef in registeredHotKeys {
            if let ref = hotKeyRef {
                UnregisterEventHotKey(ref)
            }
        }
        registeredHotKeys.removeAll()
        
        // Remove event handler
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
    }
    
    private func installCarbonEventHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), 
                                      eventKind: UInt32(kEventHotKeyPressed))
        
        let callback: EventHandlerUPP = { (nextHandler, event, userData) -> OSStatus in
            guard let userData = userData else { return OSStatus(eventNotHandledErr) }
            
            // Get hotkey ID
            var hotKeyID = EventHotKeyID(signature: 0, id: 0)
            let result = GetEventParameter(event, 
                                          EventParamName(kEventParamDirectObject),
                                          EventParamType(typeEventHotKeyID), 
                                          nil,
                                          MemoryLayout<EventHotKeyID>.size, 
                                          nil, 
                                          &hotKeyID)
            
            guard result == noErr else { return OSStatus(eventNotHandledErr) }
            
            // Call appropriate callback
            let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
            manager.handleCarbonHotKey(id: hotKeyID.id)
            
            return noErr
        }
        
        InstallEventHandler(GetApplicationEventTarget(), 
                           callback, 
                           1, 
                           &eventType, 
                           Unmanaged.passUnretained(self).toOpaque(), 
                           &eventHandler)
    }
    
    private func registerHotKey(id: HotKeyID, keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        var hotKeyRef: EventHotKeyRef?
        let carbonMods = carbonModifiers(from: modifiers)
        let hotKeyID = EventHotKeyID(signature: fourCharCode("aura"), id: id.rawValue)
        
        let status = RegisterEventHotKey(UInt32(keyCode), 
                                        carbonMods,
                                        hotKeyID,
                                        GetApplicationEventTarget(), 
                                        0, 
                                        &hotKeyRef)
        
        if status == noErr {
            registeredHotKeys.append(hotKeyRef)
        } else {
            print("Failed to register hotkey \(id) with status: \(status)")
        }
    }
    
    private func handleCarbonHotKey(id: UInt32) {
        guard let hotKeyID = HotKeyID(rawValue: id) else { return }
        
        DispatchQueue.main.async { [weak self] in
            switch hotKeyID {
            case .screenshot:
                self?.onScreenshotTriggered?()
            case .ocr:
                self?.onOCRTriggered?()
            case .translation:
                self?.onTranslationTriggered?()
            case .repeatAction:
                self?.onRepeatTriggered?()
            case .settings:
                self?.onSettingsTriggered?()
            }
        }
    }
    
    private func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var carbon: UInt32 = 0
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        if flags.contains(.shift) { carbon |= UInt32(shiftKey) }
        if flags.contains(.option) { carbon |= UInt32(optionKey) }
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        return carbon
    }
    
    private func fourCharCode(_ string: String) -> FourCharCode {
        assert(string.count == 4, "FourCharCode string must be exactly 4 characters")
        var result: FourCharCode = 0
        for char in string.utf16 {
            result = (result << 8) + FourCharCode(char)
        }
        return result
    }
    
    // MARK: - Update Methods
    
    func updateScreenshotHotKey(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        self.screenshotKey = keyCode
        self.screenshotMods = modifiers
        // Re-register hotkeys if monitoring is active
        if eventHandler != nil {
            startMonitoring()
        }
    }
    
    func updateOCRHotKey(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        self.ocrKey = keyCode
        self.ocrMods = modifiers
        if eventHandler != nil {
            startMonitoring()
        }
    }
    
    func updateRepeatHotKey(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        self.repeatKey = keyCode
        self.repeatMods = modifiers
        if eventHandler != nil {
            startMonitoring()
        }
    }
    
    func updateCancelHotKey(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        self.cancelKey = keyCode
        self.cancelMods = modifiers
        // Cancel is not a global hotkey, so no re-registration needed
    }
    
    func updateTranslationHotKey(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        self.translationKey = keyCode
        self.translationMods = modifiers
        if eventHandler != nil {
            startMonitoring()
        }
    }
    
    func updateSettingsHotKey(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        self.settingsKey = keyCode
        self.settingsMods = modifiers
        if eventHandler != nil {
            startMonitoring()
        }
    }
}
