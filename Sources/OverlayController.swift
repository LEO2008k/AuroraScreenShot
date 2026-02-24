// This program was developed by Levko Kravchuk with the help of Vibe Coding
import Cocoa
import SwiftUI

class OverlayController: NSWindowController {
    private var eventMonitor: Any?
    var viewModel: OverlayViewModel // Exposed for testing if needed
    
    override init(window: NSWindow?) {
        self.viewModel = OverlayViewModel()
        super.init(window: window)
    }
    
    required init?(coder: NSCoder) {
        self.viewModel = OverlayViewModel()
        super.init(coder: coder)
    }
    
    convenience init(image: CGImage, screen: NSScreen, isQuickOCR: Bool = false, isTranslationMode: Bool = false) {
        let screenRect = screen.frame
        let window = EditingOverlayWindow(
            contentRect: screenRect,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.acceptsMouseMovedEvents = true
        
        // Position window on specific screen
        window.setFrame(screenRect, display: true)
        
        self.init(window: window)
        
        // Initialize ViewModel
        let vm = OverlayViewModel()
        self.viewModel = vm
        
        let view = OverlayView(image: image, isQuickOCR: isQuickOCR, isTranslationMode: isTranslationMode, onClose: { [weak self] in
            print("onClose called")
            self?.closeOverlay()
        }, viewModel: vm) // Pass ViewModel
        
        window.contentView = NSHostingView(rootView: view)
        window.makeFirstResponder(window.contentView)
        
        // Add local event monitor for ESC and Brush Size keys
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            
            if event.keyCode == 53 { // ESC
                print("ESC key pressed")
                self.closeOverlay()
                return nil
            }
            
            // Brush Size: [ and ]
            if event.characters == "[" {
                DispatchQueue.main.async {
                    self.viewModel.strokeWidth = max(1, self.viewModel.strokeWidth - 2)
                }
                return nil
            }
            if event.characters == "]" {
                DispatchQueue.main.async {
                    self.viewModel.strokeWidth = min(50, self.viewModel.strokeWidth + 2)
                }
                return nil
            }
            
            return event
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleClose), name: Notification.Name("CloseOverlay"), object: nil)
    }
    
    @objc func handleClose() {
        closeOverlay()
    }
    
    func closeOverlay() {
        print("Closing overlay...")
        
        // 1. Remove event monitor
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        
        // 2. Remove notification observer to break retain cycle
        NotificationCenter.default.removeObserver(self)
        
        // 3. Reset ViewModel to release drawings data
        viewModel.reset()
        
        // 4. Break SwiftUI hosting view - this releases the CGImage
        if let w = window {
            w.contentView = nil
            w.orderOut(nil)
            w.close()
        }
        
        // 5. Clear reference in app delegate
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.overlayController = nil
        }
        
        // 6. Hint system to reclaim memory after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            autoreleasepool {
                // Force pending autorelease pool drain
            }
            print("🧹 Memory cleanup hint sent")
        }
        
        print("Overlay closed")
    }
    
    deinit {
        print("OverlayController deinit - freeing memory")
        NotificationCenter.default.removeObserver(self)
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        window?.contentView = nil
        window?.close()
    }
}

// Custom Window subclass to allow Key Window status even with .borderless style
class EditingOverlayWindow: NSWindow {
    override var canBecomeKey: Bool {
        return true
    }
    override var canBecomeMain: Bool {
        return true
    }
}
