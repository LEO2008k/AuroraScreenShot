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
        
        // Determine quality settings - support three levels
        let quality = SettingsManager.shared.quality
        var imageOptions: CGWindowImageOption = [] // Default is empty (Nominal Resolution)

        switch quality {
        case .maximum:
            // Use BestResolution to capture full backing store pixels (Retina 2x, etc.)
            // capable of capturing HDR/Deep Color if the display supports it.
            imageOptions = [.bestResolution]
            print("Using maximum quality (BestResolution/HDR capable)")
        case .medium:
            // Medium/Minimum use Nominal Resolution (1x)
            print("Using medium quality (1x nominal) - Balanced")
        case .minimum:
            print("Using minimum quality (1x nominal) - Low memory")
        }
        
        // Capture screen
        guard let rawImage = CGWindowListCreateImage(
            captureRect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            imageOptions
        ) else {
            print("Error: CGWindowListCreateImage failed")
            return nil
        }
        
        // Check Memory Limits and Resize if needed
        let width = rawImage.width
        let height = rawImage.height
        let estimatedBytes = width * height * 4 // 4 bytes per pixel (RGBA)
        let limitBytes = quality.maxMemoryBytes
        
        print("Captured size: \(width)x\(height), Est. Memory: \(estimatedBytes / 1024 / 1024) MB, Limit: \(limitBytes / 1024 / 1024) MB")
        
        if estimatedBytes > limitBytes {
            print("⚠️ Memory limit exceeded! Downscaling...")
            // Calculate scale to fit within limit (area ratio)
            let scale = sqrt(Double(limitBytes) / Double(estimatedBytes))
            let newWidth = Int(Double(width) * scale)
            let newHeight = Int(Double(height) * scale)
            
            print("Resizing to: \(newWidth)x\(newHeight) (Scale: \(String(format: "%.2f", scale)))")
            
            // Create context for resizing
            let colorSpace = rawImage.colorSpace ?? CGColorSpaceCreateDeviceRGB()
            guard let context = CGContext(
                data: nil,
                width: newWidth,
                height: newHeight,
                bitsPerComponent: rawImage.bitsPerComponent,
                bytesPerRow: 0, // Calculate automatically
                space: colorSpace,
                bitmapInfo: rawImage.bitmapInfo.rawValue
            ) else {
                print("Failed to create resize context, using original")
                return (rawImage, screen)
            }
            
            // Draw original image into smaller context
            context.interpolationQuality = .high
            context.draw(rawImage, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
            
            if let resizedImage = context.makeImage() {
                return (resizedImage, screen)
            }
        }
        
        return (rawImage, screen)
    }
}
