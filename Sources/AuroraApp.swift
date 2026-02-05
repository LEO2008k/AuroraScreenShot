// This program was developed by Levko Kravchuk with the help of Vibe Coding
import Cocoa
import SwiftUI

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
        
        // If we are missing permissions, show the setup window
        // Note: For development ease, we might want to check if it's the first run, 
        // but checking actual permissions is safer.
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
        
        // Quick OCR Menu Item
        let ocrShortcut = SettingsManager.shared.ocrShortcut
        let ocrItem = NSMenuItem(title: "Quick OCR", action: #selector(captureOCR), keyEquivalent: KeyboardShortcuts.keyString(for: ocrShortcut.keyCode))
        ocrItem.keyEquivalentModifierMask = ocrShortcut.nsModifierFlags
        menu.addItem(ocrItem)
        
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
        
        HotKeyManager.shared.startMonitoring()
    }
    
    @objc func openPreferences() {
        if preferencesWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
                styleMask: [.titled, .closable],
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

    @objc func captureOCR() {
        print("Quick OCR triggered")
        startCapture(ocrOnly: true)
    }

    func startCapture(ocrOnly: Bool) {
        print("Capture screen triggered (OCR Only: \(ocrOnly))")
        
        // Recursion Guard: Restart behavior
        // If overlay is already active, close it and start a NEW capture (Quick Restart)
        if let window = overlayController?.window, window.isVisible {
            print("Overlay active. Closing to restart capture...")
            overlayController?.closeOverlay()
            
            // Wait slightly for cleanup, then recurse
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.startCapture(ocrOnly: ocrOnly)
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
            
            // Capture active screen (where mouse is)
            guard let result = ScreenCapture.captureActiveScreen() else {
                print("Failed to capture screen")
                self.statusItem.button?.isHidden = false
                return
            }
            
            // Restore menu bar icon
            self.statusItem.button?.isHidden = false
            
            // Show overlay with captured image on the correct screen
            self.overlayController = OverlayController(image: result.image, screen: result.screen, isQuickOCR: ocrOnly)
            self.overlayController?.showWindow(nil)
            self.overlayController?.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
