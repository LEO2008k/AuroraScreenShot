
import SwiftUI
import AppKit

extension NSColor {
    // Convert NSColor to Hex String (e.g., "#FF0000")
    func toHex() -> String {
        guard let rgbColor = self.usingColorSpace(.sRGB) else {
            return "#000000"
        }
        let red = Int(round(rgbColor.redComponent * 0xFF))
        let green = Int(round(rgbColor.greenComponent * 0xFF))
        let blue = Int(round(rgbColor.blueComponent * 0xFF))
        return String(format: "#%02X%02X%02X", red, green, blue)
    }
}


