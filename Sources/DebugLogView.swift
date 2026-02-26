// This program was developed by Levko Kravchuk with the help of Vibe Coding
import SwiftUI

struct DebugLogView: View {
    let logText: String
    let onCopy: () -> Void
    let onClear: () -> Void
    let onShowInFinder: () -> Void
    
    @State private var refreshedText: String = ""
    
    var displayText: String { refreshedText.isEmpty ? logText : refreshedText }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("🐛 Debug Log")
                    .font(.headline)
                Spacer()
                if let url = DebugLogger.shared.logFileURL {
                    Text(url.path)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .padding()
            
            Divider()
            
            // Log content
            ScrollView {
                ScrollViewReader { proxy in
                    Text(displayText.isEmpty ? "[No log entries yet. Use the app and come back.]" : displayText)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .id("bottom")
                    .onAppear {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
            .background(Color(NSColor.textBackgroundColor))
            
            Divider()
            
            // Action buttons
            HStack(spacing: 12) {
                Button("🔄 Refresh") {
                    refreshedText = DebugLogger.shared.readLog()
                }
                
                Button("📋 Copy All") {
                    onCopy()
                }
                
                Button("📂 Show in Finder") {
                    onShowInFinder()
                }
                
                Spacer()
                
                Button("🗑 Clear Log") {
                    onClear()
                    refreshedText = ""
                }
                .foregroundColor(.red)
            }
            .padding()
        }
        .frame(minWidth: 600, minHeight: 400)
        .onAppear {
            refreshedText = DebugLogger.shared.readLog()
        }
    }
}
