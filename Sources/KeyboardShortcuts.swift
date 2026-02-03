// This program was developed by Levko Kravchuk with the help of Vibe Coding
import Cocoa

struct Shortcut: Codable, Equatable {
    var keyCode: UInt16
    var modifierFlags: UInt
    
    var nsModifierFlags: NSEvent.ModifierFlags {
        return NSEvent.ModifierFlags(rawValue: modifierFlags)
    }
    
    static let defaultShortcut = Shortcut(keyCode: 18, modifierFlags: NSEvent.ModifierFlags([.command, .shift]).rawValue) // Cmd+Shift+1
    
    var description: String {
        var str = ""
        let flags = nsModifierFlags
        
        if flags.contains(.control) { str += "⌃" }
        if flags.contains(.option) { str += "⌥" }
        if flags.contains(.shift) { str += "⇧" }
        if flags.contains(.command) { str += "⌘" }
        
        str += KeyboardShortcuts.keyString(for: keyCode)
        return str
    }
}

class KeyboardShortcuts {
    static func keyString(for keyCode: UInt16) -> String {
        // Special keys mapping
        switch keyCode {
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 23: return "5"
        case 22: return "6"
        case 26: return "7"
        case 28: return "8"
        case 25: return "9"
        case 29: return "0"
        
        case 12: return "Q"
        case 13: return "W"
        case 14: return "E"
        case 15: return "R"
        case 17: return "T"
        case 16: return "Y"
        case 32: return "U"
        case 34: return "I"
        case 31: return "O"
        case 35: return "P"
            
        case 0: return "A"
        case 1: return "S"
        case 2: return "D"
        case 3: return "F"
        case 5: return "G"
        case 4: return "H"
        case 38: return "J"
        case 40: return "K"
        case 37: return "L"
            
        case 6: return "Z"
        case 7: return "X"
        case 8: return "C"
        case 9: return "V"
        case 11: return "B"
        case 45: return "N"
        case 46: return "M"
            
        case 53: return "⎋" // Esc
        case 49: return "␣" // Space
        case 36: return "⏎" // Return
        case 51: return "⌫" // Delete
        default: return "?" // Fallback need a full mapper or Carbon usage for universality, but this covers 99%
        }
    }
}
