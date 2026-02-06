// This program was developed by Levko Kravchuk with the help of Vibe Coding
import Cocoa
import CoreGraphics

struct ScreenCapture {
    /// Captures the main screen content as a CGImage.
    /// Captures the screen containing the mouse cursor (including windows)
    static func captureActiveScreen() -> (image: CGImage, screen: NSScreen)? {
        let mouseLocation = NSEvent.mouseLocation
        
        // Debug: Print available screens
        print("Available screens: \(NSScreen.screens.count)")
        for (i, screen) in NSScreen.screens.enumerated() {
            print("  Screen \(i): frame=\(screen.frame)")
        }
        print("Mouse location: \(mouseLocation)")
        
        // Find screen containing mouse
        var activeScreen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) })
        
        // Fallback to main screen if mouse not found on any
        if activeScreen == nil {
            print("Warning: Mouse not on any screen, using main screen")
            activeScreen = NSScreen.main
        }
        
        guard let screen = activeScreen else {
            print("Error: No screen available")
            return nil
        }
        
        print("Selected screen: \(screen.frame)")
        
        // Convert NSScreen frame to CGRect for CGWindowListCreateImage
        // NSScreen uses bottom-left origin, CGWindowListCreateImage uses top-left
        let mainScreenHeight = NSScreen.screens[0].frame.height
        let captureRect = CGRect(
            x: screen.frame.origin.x,
            y: mainScreenHeight - screen.frame.origin.y - screen.frame.height,
            width: screen.frame.width,
            height: screen.frame.height
        )
        
        print("Capture rect: \(captureRect)")
        
        // Check for Screen Recording Permission
        if !CGPreflightScreenCaptureAccess() {
            print("WARNING: Screen Recording permission missing. Requesting access...")
            CGRequestScreenCaptureAccess()
        }
        
        // Respect downscale setting to reduce memory usage
        // For 5K displays, .bestResolution can use 2GB+ RAM
        // .nominalResolution captures at 1x instead of 2x Retina
        let imageOptions: CGWindowImageOption
        if SettingsManager.shared.downscaleRetina {
            imageOptions = [.nominalResolution]
            print("Using nominal resolution (1x) to reduce memory")
        } else {
            imageOptions = [.bestResolution]
            print("Using best resolution (2x Retina)")
        }
        
        // Use CGWindowListCreateImage to capture ALL windows on screen
        if let image = CGWindowListCreateImage(
            captureRect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            imageOptions
        ) {
            print("Captured image size: \(image.width)x\(image.height)")
            return (image, screen)
        }
        
        print("Error: CGWindowListCreateImage failed")
        return nil
    }
}
