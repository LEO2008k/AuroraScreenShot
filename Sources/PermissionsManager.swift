// This program was developed by Levko Kravchuk with the help of Vibe Coding
import Cocoa
import Combine

class PermissionsManager: ObservableObject {
    static let shared = PermissionsManager()
    
    @Published var hasScreenRecording = false
    @Published var hasAccessibility = false
    
    init() {
        check()
    }
    
    func check() {
        // Screen Recording
        hasScreenRecording = CGPreflightScreenCaptureAccess()
        
        // Accessibility
        hasAccessibility = AXIsProcessTrusted()
    }
    
    func requestScreenRecording() {
        // This usually only works if the app has attempted to capture before, 
        // but explicit call can trigger the prompt if not already denied.
        CGRequestScreenCaptureAccess()
        // Re-check after small delay? The system prompt blocks execution usually? No, it's async UI.
        // We rely on user clicking "Check Again".
    }
    
    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
    
    func openSystemSettings(for type: String) {
        // Deep linking to System Settings
        // macOS 13+ changes URLs, but let's try standard ones
        
        let url: URL?
        if type == "accessibility" {
            url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        } else {
             url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
        }
        
        if let url = url {
            NSWorkspace.shared.open(url)
        }
    }
}
