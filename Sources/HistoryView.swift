import SwiftUI
import Cocoa

struct HistoryView: View {
    @ObservedObject var manager = HistoryManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Translation History")
                    .font(.headline)
                Spacer()
                
                if !manager.history.isEmpty {
                    Button(action: {
                        manager.clearAll()
                    }) {
                        Label("Clear All", systemImage: "trash")
                            .foregroundColor(.red)
                    }
                }
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            if manager.history.isEmpty {
                VStack {
                    Spacer()
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.3))
                        .padding()
                    Text("No history yet")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    Text("Enable 'Save Translation History' in Preferences.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.controlBackgroundColor))
            } else {
                List {
                    ForEach(manager.history) { item in
                        HistoryRow(item: item)
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
        .frame(minWidth: 600, minHeight: 400)
    }
}

struct HistoryRow: View {
    let item: HistoryItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header: Date & Langs
            HStack {
                Text(item.date, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(item.date, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Text(item.sourceLanguage)
                    Image(systemName: "arrow.right")
                    Text(item.targetLanguage)
                }
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(4)
            }
            
            // Content
            HStack(alignment: .top, spacing: 10) {
                // Original
                VStack(alignment: .leading, spacing: 4) {
                    Text("Original:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(item.originalText)
                        .font(.system(size: 13))
                        .lineLimit(4)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Divider()
                
                // Translated
                VStack(alignment: .leading, spacing: 4) {
                    Text("Translation:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(item.translatedText)
                        .font(.system(size: 13))
                        .lineLimit(4)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
            
            // Actions
            HStack {
                Spacer()
                
                Button(action: { copy(item.originalText) }) {
                    Label("Copy Original", systemImage: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                
                Text("|").foregroundColor(.secondary)
                
                Button(action: { copy(item.translatedText) }) {
                    Label("Copy Translation", systemImage: "doc.on.doc.fill")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 6)
    }
    
    func copy(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}

class HistoryWindowController: NSWindowController {
    static let shared = HistoryWindowController()
    
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Translation History"
        window.center()
        window.isReleasedWhenClosed = false
        
        self.init(window: window)
        
        let view = HistoryView()
        window.contentView = NSHostingView(rootView: view)
    }
    
    func show() {
        if self.window == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 700, height: 600),
                styleMask: [.titled, .closable, .resizable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Translation History"
            window.center()
            window.isReleasedWhenClosed = false
            self.window = window
            let view = HistoryView()
            window.contentView = NSHostingView(rootView: view)
        }
        
        self.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
