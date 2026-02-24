// This program was developed by Levko Kravchuk with the help of Vibe Coding
import Cocoa
import CoreGraphics

struct ScreenCapture {
    /// Captures the main screen content as a CGImage.
    /// Captures the screen containing the mouse cursor (including windows)
    /// MEMORY: Returns a "detached" CGImage copy (not IOSurface-backed) so memory can be freed by ARC
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
        
        // Capture screen within autoreleasepool to help release transient objects
        return autoreleasepool {
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
                
                if let resized = createDetachedCopy(of: rawImage, width: newWidth, height: newHeight) {
                    return (resized, screen)
                }
            }
            
            // MEMORY FIX: Create a "detached" copy of the CGImage
            // CGWindowListCreateImage returns an IOSurface-backed image.
            // IOSurface memory is mapped into our process and may NOT be freed when the CGImage
            // reference is released. By copying pixels into a regular CGContext-backed image,
            // we allow the IOSurface to be unmapped and the memory to be reclaimed by ARC.
            if let detached = createDetachedCopy(of: rawImage, width: width, height: height) {
                print("✅ Created detached copy (\(width)x\(height)), IOSurface can be freed")
                return (detached, screen)
            }
            
            // Fallback: return raw image if copy fails (shouldn't happen)
            print("⚠️ Could not create detached copy, using IOSurface-backed image")
            return (rawImage, screen)
        }
    }
    
    /// Creates a regular bitmap-backed CGImage copy from any source CGImage.
    /// This ensures the resulting image is NOT backed by IOSurface or other shared memory.
    private static func createDetachedCopy(of source: CGImage, width: Int, height: Int) -> CGImage? {
        let colorSpace = source.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0, // Calculate automatically
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else {
            return nil
        }
        
        context.interpolationQuality = .high
        context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }
}
