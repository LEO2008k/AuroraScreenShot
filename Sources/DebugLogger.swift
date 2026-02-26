// This program was developed by Levko Kravchuk with the help of Vibe Coding
import Foundation
import AppKit

class DebugLogger {
    static let shared = DebugLogger()
    
    private let fileName = "debug.log"
    private let maxLines = 500 // Keep log compact
    
    var logFileURL: URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let dir = appSupport.appendingPathComponent("AuroraScreenShot")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(fileName)
    }
    
    func log(_ message: String, category: String = "INFO") {
        guard UserDefaults.standard.bool(forKey: "DebugModeEnabled") else { return }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        let timestamp = formatter.string(from: Date())
        let line = "[\(timestamp)] [\(category)] \(message)\n"
        
        // Also print to Xcode console
        print(line, terminator: "")
        
        // Append to file
        guard let url = logFileURL else { return }
        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: url.path) {
                if let handle = try? FileHandle(forWritingTo: url) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                }
            } else {
                try? data.write(to: url)
            }
        }
        trimIfNeeded(url: url)
    }
    
    func readLog() -> String {
        guard let url = logFileURL,
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            return "[No log file found]"
        }
        return content
    }
    
    func clearLog() {
        guard let url = logFileURL else { return }
        try? "".write(to: url, atomically: true, encoding: .utf8)
    }
    
    func openInFinder() {
        guard let url = logFileURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
    
    private func trimIfNeeded(url: URL) {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }
        let lines = content.components(separatedBy: "\n")
        if lines.count > maxLines {
            let trimmed = lines.suffix(maxLines).joined(separator: "\n")
            try? trimmed.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
