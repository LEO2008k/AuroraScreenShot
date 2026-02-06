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
        let imageOptions: CGWindowImageOption
        
        switch quality {
        case .maximum:
            imageOptions = [.bestResolution]
            print("Using maximum quality (2x Retina) - High memory usage")
        case .medium:
            imageOptions = [.nominalResolution]
            print("Using medium quality (1x nominal) - Balanced")
        case .minimum:
            imageOptions = [.nominalResolution]
            print("Using minimum quality (1x + downscale) - Low memory")
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
        
        print("Captured raw image size: \(rawImage.width)x\(rawImage.height)")
        
        // Apply additional downscale for minimum quality
        if quality == .minimum {
            let downscaleFactor: CGFloat = 0.5
            let newWidth = Int(CGFloat(rawImage.width) * downscaleFactor)
            let newHeight = Int(CGFloat(rawImage.height) * downscaleFactor)
            
            print("Downscaling to: \(newWidth)x\(newHeight)")
            
            if let ctx = CGContext(
                data: nil,
                width: newWidth,
                height: newHeight,
                bitsPerComponent: rawImage.bitsPerComponent,
                bytesPerRow: 0,
                space: rawImage.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: rawImage.bitmapInfo.rawValue
            ) {
                ctx.interpolationQuality = .medium
                ctx.draw(rawImage, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
                if let downscaled = ctx.makeImage() {
                    print("Final downscaled image size: \(downscaled.width)x\(downscaled.height)")
                    return (downscaled, screen)
                }
            }
            
            print("Warning: Downscaling failed, using nominal resolution")
        }
        
        print("Final image size: \(rawImage.width)x\(rawImage.height)")
        return (rawImage, screen)
    }
}
