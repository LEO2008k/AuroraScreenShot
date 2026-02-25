// This program was developed by Levko Kravchuk with the help of Vibe Coding
import Cocoa
import SwiftUI

// MARK: - Clipboard Auto-Cleanup Manager
class ClipboardManager {
    static let shared = ClipboardManager()
    
    private var cleanupTimer: Timer?
    private var pasteboardChangeCount: Int = 0
    
    private init() {}
    
    /// Clipboard auto-clear delay from user settings (default 3 min, max 60 min)
    private var clipboardTimeoutSeconds: TimeInterval {
        let minutes = SettingsManager.shared.clipboardTimeoutMinutes
        return TimeInterval(max(1, min(minutes, 60))) * 60
    }
    
    /// Call after copying screenshot to clipboard. Starts auto-clear timer.
    func scheduleClipboardCleanup() {
        // Cancel any existing timer
        cleanupTimer?.invalidate()
        
        // Record current pasteboard state
        pasteboardChangeCount = NSPasteboard.general.changeCount
        
        let timeout = clipboardTimeoutSeconds
        print("📋 Clipboard cleanup scheduled in \(Int(timeout))s (\(Int(timeout/60)) min)")
        
        // Schedule cleanup
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
            self?.performClipboardCleanup()
        }
    }
    
    /// Clears the clipboard if it still contains our screenshot data
    private func performClipboardCleanup() {
        let currentChangeCount = NSPasteboard.general.changeCount
        
        // Only clear if user hasn't copied something else since we set the clipboard
        if currentChangeCount == pasteboardChangeCount {
            NSPasteboard.general.clearContents()
            print("🧹 Clipboard auto-cleared after \(Int(clipboardTimeoutSeconds/60)) min timeout")
        } else {
            print("📋 Clipboard changed by user, skipping cleanup")
        }
        
        cleanupTimer = nil
    }
    
    /// Cancel scheduled cleanup (e.g., on app quit)
    func cancelCleanup() {
        cleanupTimer?.invalidate()
        cleanupTimer = nil
    }
}

@main
struct AuroraApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory) // Hide from Dock
        
        print("Aurora Screenshot app started! Look for the icon in your Menu Bar (top right).")
        app.run()
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    
    var permissionsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let auth = PermissionsManager.shared
        auth.check()
        
        // Sync login item state with system on launch
        if SettingsManager.shared.launchAtLogin {
            SettingsManager.registerLoginItem(enabled: true)
        }
        
        // If we are missing permissions, show the setup window
        if !auth.hasScreenRecording || !auth.hasAccessibility {
            showPermissionsWindow()
        } else {
            setupMenuBar()
        }
    }
    
    var preferencesWindow: NSWindow?
    
    func showPermissionsWindow() {
        if permissionsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 450, height: 500),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "Permissions Required"
            window.center()
            window.isReleasedWhenClosed = false
            window.level = .floating
            
            let contentView = PermissionsView { [weak self] in
                self?.permissionsWindow?.close()
                self?.setupMenuBar()
            }
            
            window.contentView = NSHostingView(rootView: contentView)
            permissionsWindow = window
        }
        
        permissionsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "text.viewfinder", accessibilityDescription: "Aurora Screenshot")
        }
        
        // Initial setup
        updateMenu()
        
        // Initialize HotKey Monitoring
        updateGlobalHotkey()
        
        // Listen for changes
        NotificationCenter.default.addObserver(self, selector: #selector(refreshForHotkeyChange), name: Notification.Name("HotkeyChanged"), object: nil)
    }
    
    func updateMenu() {
        let menu = NSMenu()
        
        let shortcut = SettingsManager.shared.shortcut
        let item = NSMenuItem(title: "Take Screenshot", action: #selector(captureScreen), keyEquivalent: KeyboardShortcuts.keyString(for: shortcut.keyCode))
        item.keyEquivalentModifierMask = shortcut.nsModifierFlags
        menu.addItem(item)
        
        // Screenshot & Translate Menu Item
        let transShortcut = SettingsManager.shared.translationHotKey
        let transItem = NSMenuItem(title: "Screenshot & Translate", action: #selector(captureTranslation), keyEquivalent: KeyboardShortcuts.keyString(for: UInt16(transShortcut.0)))
        transItem.keyEquivalentModifierMask = NSEvent.ModifierFlags(rawValue: transShortcut.1)
        menu.addItem(transItem)
        
        // Quick OCR Menu Item
        let ocrShortcut = SettingsManager.shared.ocrShortcut
        let ocrItem = NSMenuItem(title: "Quick OCR", action: #selector(captureOCR), keyEquivalent: KeyboardShortcuts.keyString(for: ocrShortcut.keyCode))
        ocrItem.keyEquivalentModifierMask = ocrShortcut.nsModifierFlags
        menu.addItem(ocrItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // HDR Toggle (checkmark)
        let hdrItem = NSMenuItem(title: "Save as HDR", action: #selector(toggleHDR), keyEquivalent: "")
        hdrItem.state = SettingsManager.shared.saveAsHDR ? .on : .off
        // Show quality info in tooltip
        if SettingsManager.shared.quality == .maximum {
            hdrItem.isEnabled = true
        } else {
            hdrItem.isEnabled = false
            hdrItem.toolTip = "Requires Maximum quality"
        }
        menu.addItem(hdrItem)
        
        menu.addItem(NSMenuItem.separator())
        // Preferences with dynamic shortcut
        let prefShortcut = SettingsManager.shared.settingsShortcut
        let prefItem = NSMenuItem(title: "Preferences...", action: #selector(openPreferences), keyEquivalent: KeyboardShortcuts.keyString(for: prefShortcut.keyCode))
        prefItem.keyEquivalentModifierMask = prefShortcut.nsModifierFlags
        menu.addItem(prefItem)
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem.menu = menu
    }
    
    @objc func refreshForHotkeyChange() {
        updateMenu()
        updateGlobalHotkey()
    }
    
    func updateGlobalHotkey() {
        // Screenshot Hotkey
        let sc = SettingsManager.shared.shortcut
        HotKeyManager.shared.updateScreenshotHotKey(keyCode: sc.keyCode, modifiers: sc.nsModifierFlags)
        
        // OCR Hotkey
        let ocrSc = SettingsManager.shared.ocrShortcut
        HotKeyManager.shared.updateOCRHotKey(keyCode: ocrSc.keyCode, modifiers: ocrSc.nsModifierFlags)
        
        // Repeat Hotkey
        let repSc = SettingsManager.shared.repeatShortcut
        HotKeyManager.shared.updateRepeatHotKey(keyCode: repSc.keyCode, modifiers: repSc.nsModifierFlags)

        // Settings Hotkey
        let setSc = SettingsManager.shared.settingsShortcut
        HotKeyManager.shared.updateSettingsHotKey(keyCode: setSc.keyCode, modifiers: setSc.nsModifierFlags)
        
        // Cancel Hotkey
        let canSc = SettingsManager.shared.cancelShortcut
        HotKeyManager.shared.updateCancelHotKey(keyCode: canSc.keyCode, modifiers: canSc.nsModifierFlags)
        
        // Translation Hotkey
        let transSc = SettingsManager.shared.translationHotKey
        HotKeyManager.shared.updateTranslationHotKey(keyCode: UInt16(transSc.0), modifiers: NSEvent.ModifierFlags(rawValue: transSc.1))
        
        HotKeyManager.shared.onScreenshotTriggered = { [weak self] in
            DispatchQueue.main.async {
                self?.captureScreen()
            }
        }
        
        HotKeyManager.shared.onOCRTriggered = { [weak self] in
            DispatchQueue.main.async {
                self?.captureOCR()
            }
        }
        
        HotKeyManager.shared.onSettingsTriggered = { [weak self] in
            DispatchQueue.main.async {
                self?.openPreferences() // Bring to front
                NSApp.activate(ignoringOtherApps: true)
            }
        }
        
        HotKeyManager.shared.onRepeatTriggered = { [weak self] in
            DispatchQueue.main.async {
                // TODO: Implement actual "Repeat Last Selection" logic
                // For now, just trigger normal capture
                self?.captureScreen()
            }
        }
        
        HotKeyManager.shared.onCancelTriggered = {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Notification.Name("CloseOverlay"), object: nil)
            }
            }

        
        HotKeyManager.shared.onTranslationTriggered = { [weak self] in
            DispatchQueue.main.async {
                self?.captureTranslation()
            }
        }
        
        HotKeyManager.shared.startMonitoring()
    }
    
    @objc func openPreferences() {
        if preferencesWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 900, height: 650),
                styleMask: [.titled, .closable, .resizable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Preferences"
            window.center()
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: PreferencesView())
            preferencesWindow = window
        }
        
        preferencesWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    // Legacy method removed: setSaveLocation -> Now in Preferences
    
    var overlayController: OverlayController?
    
    // Explicit cleanup helper - AGGRESSIVE memory release
    func cleanupOverlay() {
        if let oc = overlayController {
            oc.viewModel.reset()
            oc.closeOverlay()
        }
        overlayController = nil
        
        // Force autorelease pool drain and memory reclaim
        DispatchQueue.main.async {
            autoreleasepool {
                // Drain any pending autoreleased objects (CGImage, NSBitmapImageRep, etc.)
            }
            // Hint the system to reclaim unused memory pages
            malloc_zone_pressure_relief(nil, 0)
            print("🧹 Aggressive memory cleanup complete")
        }
    }
    
    var resultWindowController: OCRResultWindowController? // Keep reference to prevent dealloc

    @objc func captureScreen() {
        startCapture(ocrOnly: false)
    }
    
    @objc func toggleTimestamp() {
        SettingsManager.shared.showTimestamp.toggle()
        updateMenu()
    }
    
    @objc func toggleWatermark() {
        SettingsManager.shared.showWatermark.toggle()
        updateMenu()
    }
    
    @objc func toggleHDR() {
        SettingsManager.shared.saveAsHDR.toggle()
        updateMenu()
        print("💎 HDR mode: \(SettingsManager.shared.saveAsHDR ? "ON" : "OFF")")
    }

    @objc func captureOCR() {
        print("Quick OCR triggered")
        startCapture(ocrOnly: true)
    }
    
    @objc func captureTranslation() {
        print("Translation Capture triggered")
        startCapture(ocrOnly: false, isTranslationMode: true)
    }

    func startCapture(ocrOnly: Bool, isTranslationMode: Bool = false) {
        print("Capture screen triggered (OCR Only: \(ocrOnly), Translation: \(isTranslationMode))")
        
        // Recursion Guard: Restart behavior
        // If overlay is already active, close it and start a NEW capture (Quick Restart)
        if let window = overlayController?.window, window.isVisible {
            print("Overlay active. Closing to restart capture...")
            overlayController?.closeOverlay()
            
            // Wait slightly for cleanup, then recurse
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.startCapture(ocrOnly: ocrOnly, isTranslationMode: isTranslationMode)
            }
            return
        }

        // Hide menu bar icon temporarily to get clean screenshot
        if let button = statusItem.button {
            button.isHidden = true
        }
        
        // Small delay to let UI update
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            
            autoreleasepool {
                // Capture active screen (where mouse is)
                guard let result = ScreenCapture.captureActiveScreen() else {
                    print("Failed to capture screen")
                    self.statusItem.button?.isHidden = false
                    return
                }
                
                // Restore menu bar icon
                self.statusItem.button?.isHidden = false
                
                // MEMORY FIX: Ensure previous overlay is fully released before creating new one
                if self.overlayController != nil {
                    self.cleanupOverlay()
                }
                
                // Show overlay with captured image on the correct screen
                self.overlayController = OverlayController(image: result.image, screen: result.screen, isQuickOCR: ocrOnly, isTranslationMode: isTranslationMode)
                self.overlayController?.showWindow(nil)
                self.overlayController?.window?.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
}
