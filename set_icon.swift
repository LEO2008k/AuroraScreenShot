import AppKit

// Usage: swift set_icon.swift <path/to/icon.icns> <path/to/target_file>

let args = CommandLine.arguments
guard args.count == 3 else {
    print("Usage: swift set_icon.swift <icon_path> <target_path>")
    exit(1)
}

let iconPath = args[1]
let targetPath = args[2]

guard let image = NSImage(contentsOfFile: iconPath) else {
    print("Error: Could not load icon from \(iconPath)")
    exit(1)
}

let success = NSWorkspace.shared.setIcon(image, forFile: targetPath, options: [])

if success {
    print("✅ Icon applied to \(targetPath)")
} else {
    print("❌ Failed to apply icon.")
    exit(1)
}
