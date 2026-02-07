// This program was developed by Levko Kravchuk with the help of Vibe Coding
import Foundation
import SwiftUI

struct OCRHistoryEntry: Codable, Identifiable {
    let id: UUID
    let text: String
    let timestamp: Date
    
    init(id: UUID = UUID(), text: String, timestamp: Date = Date()) {
        self.id = id
        self.text = text
        self.timestamp = timestamp
    }
}

class OCRHistoryManager: ObservableObject {
    static let shared = OCRHistoryManager()
    
    @Published var history: [OCRHistoryEntry] = []
    
    private let fileManager = FileManager.default
    private let fileName = "ocr_history.json"
    
    var historyFileURL: URL? {
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let appDir = appSupport.appendingPathComponent("com.levkokravchuk.AuroraScreenshot")
        try? fileManager.createDirectory(at: appDir, withIntermediateDirectories: true)
        return appDir.appendingPathComponent(fileName)
    }
    
    private init() {
        loadHistory()
        cleanOldEntries()
    }
    
    func addEntry(text: String) {
        guard SettingsManager.shared.saveOCRHistory else { return }
        
        let entry = OCRHistoryEntry(text: text)
        history.insert(entry, at: 0)
        saveHistory()
        cleanOldEntries()
    }
    
    func clearAll() {
        history.removeAll()
        saveHistory()
    }
    
    func deleteEntry(_ entry: OCRHistoryEntry) {
        history.removeAll { $0.id == entry.id }
        saveHistory()
    }
    
    private func loadHistory() {
        guard let url = historyFileURL else { return }
        guard fileManager.fileExists(atPath: url.path) else { return }
        
        do {
            let data = try Data(contentsOf: url)
            history = try JSONDecoder().decode([OCRHistoryEntry].self, from: data)
        } catch {
            print("Failed to load OCR history: \(error)")
        }
    }
    
    private func saveHistory() {
        guard let url = historyFileURL else { return }
        
        do {
            let data = try JSONEncoder().encode(history)
            try data.write(to: url)
        } catch {
            print("Failed to save OCR history: \(error)")
        }
    }
    
    func cleanOldEntries() {
        let retentionHours = SettingsManager.shared.ocrHistoryRetentionHours
        guard retentionHours > 0 else { return }
        
        let cutoffDate = Date().addingTimeInterval(-Double(retentionHours) * 3600)
        history.removeAll { $0.timestamp < cutoffDate }
        saveHistory()
    }
}

// OCR History Window Controller
class OCRHistoryWindowController: NSWindowController {
    static let shared = OCRHistoryWindowController()
    
    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "OCR History"
        window.center()
        window.isReleasedWhenClosed = false
        
        super.init(window: window)
        
        let view = OCRHistoryView()
        window.contentView = NSHostingView(rootView: view)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func show() {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// OCR History SwiftUI View
struct OCRHistoryView: View {
    @ObservedObject var manager = OCRHistoryManager.shared
    @State private var searchText = ""
    
    var filteredHistory: [OCRHistoryEntry] {
        if searchText.isEmpty {
            return manager.history
        }
        return manager.history.filter { $0.text.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "text.viewfinder")
                    .font(.title2)
                    .foregroundColor(.blue)
                Text("OCR History")
                    .font(.headline)
                Spacer()
                Text("\(manager.history.count) items")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search OCR text...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
            .padding()
            
            // List
            if filteredHistory.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text(searchText.isEmpty ? "No OCR history" : "No results found")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(filteredHistory) { entry in
                        OCRHistoryRow(entry: entry)
                    }
                }
            }
            
            Divider()
            
            // Footer
            HStack {
                Button("Clear All", role: .destructive) {
                    manager.clearAll()
                }
                .disabled(manager.history.isEmpty)
                
                Spacer()
                
                if let url = manager.historyFileURL {
                    Button("Show in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    }
                    .font(.caption)
                }
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
        }
    }
}

struct OCRHistoryRow: View {
    let entry: OCRHistoryEntry
    @State private var isHovering = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.text.prefix(100))
                    .lineLimit(2)
                    .font(.system(size: 13))
                Spacer()
                
                if isHovering {
                    HStack(spacing: 8) {
                        Button(action: copyText) {
                            Image(systemName: "doc.on.doc")
                        }
                        .buttonStyle(.plain)
                        .help("Copy")
                        
                        Button(action: deleteEntry) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                        .help("Delete")
                    }
                }
            }
            
            Text(formatDate(entry.timestamp))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
        .onHover { hovering in
            isHovering = hovering
        }
    }
    
    func copyText() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(entry.text, forType: .string)
    }
    
    func deleteEntry() {
        OCRHistoryManager.shared.deleteEntry(entry)
    }
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
