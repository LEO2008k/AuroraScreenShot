// This program was developed by Levko Kravchuk with the help of Vibe Coding
import SwiftUI
import Cocoa

struct OCRResultView: View {
    @State var text: String
    var onClose: () -> Void
    
    @State private var translatedText: String = ""
    @State private var lastTranslatedInput: String = ""
    @State private var sourceLanguage: String = "Auto"
    @State private var targetLanguage: String = SettingsManager.shared.defaultTargetLanguage
    @State private var isTranslating = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showLengthWarning = false
    
    // Appearance Settings
    @AppStorage("ocrFontSize") var fontSize: Double = 14.0
    @AppStorage("ocrEditorBgMode") var bgMode: String = "System"
    @AppStorage("ocrEditorCustomColor") var customColorHex: String = "#1E1E1E"
    
    var editorBackgroundColor: Color {
        switch bgMode {
        case "Dark": return Color.black
        case "Light": return Color.white
        case "Custom": return Color(hex: customColorHex) ?? Color(NSColor.controlBackgroundColor)
        default: return Color(NSColor.controlBackgroundColor)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            // Header
            HStack {
                Button(action: {
                    NSApp.sendAction(Selector("openPreferences"), to: nil, from: nil)
                }) {
                    Image(systemName: "gearshape.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Settings")
                .padding(.trailing, 4)
                
                Text("OCR Editor")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: {
                    HistoryWindowController.shared.show()
                }) {
                    Label("History", systemImage: "clock")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .padding(.trailing, 8)
                
                Button(action: shareContent) {
                    Image(systemName: "square.and.arrow.up")
                }
                .buttonStyle(.plain)
                .help("Share Content")
                .padding(.trailing, 8)
                
                Button("Close", action: onClose)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Content Area (Split)
            VSplitView {
                // Top: Original Text
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                         Text("Original Text")
                             .font(.caption)
                             .foregroundColor(.secondary)
                         Spacer()
                         
                         Text(getStats(text))
                             .font(.caption2)
                             .foregroundColor(text.count > 2000 ? .orange : .secondary)
                    }
                    .padding(.horizontal)
                    
                    MacEditorView(
                        text: $text, 
                        font: .systemFont(ofSize: CGFloat(fontSize)), 
                        textColor: computedTextColor,
                        backgroundColor: NSColor(editorBackgroundColor)
                    )
                    .padding(5)
                    .overlay(
                        RoundedRectangle(cornerRadius: 0)
                            .stroke(showCopyFlash && activeCopyTarget == .original ? 
                                    LinearGradient(colors: [.cyan, .green, .purple], startPoint: .leading, endPoint: .trailing) : 
                                    LinearGradient(colors: [.clear], startPoint: .leading, endPoint: .trailing), 
                                    lineWidth: 2)
                    )
                }
                .frame(minHeight: 100)
                
                // Bottom: Translation
                if !translatedText.isEmpty || isTranslating {
                     VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text("Translation (\(sourceLanguage) → \(targetLanguage))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            
                            if !translatedText.isEmpty {
                                Text(getStats(translatedText))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal)
                        
                        ZStack {
                            MacEditorView(
                                text: $translatedText, 
                                font: .systemFont(ofSize: CGFloat(fontSize)), 
                                textColor: computedTextColor,
                                backgroundColor: NSColor(editorBackgroundColor)
                            )
                            .padding(5)
                            .overlay(
                                RoundedRectangle(cornerRadius: 0)
                                    .stroke(showCopyFlash && activeCopyTarget == .translation ? 
                                            LinearGradient(colors: [.purple, .pink, .orange], startPoint: .leading, endPoint: .trailing) : 
                                            LinearGradient(colors: [.clear], startPoint: .leading, endPoint: .trailing), 
                                            lineWidth: 2)
                            )
                            
                            if isTranslating {
                                ProgressView("Translating via Ollama...")
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .background(Color.black.opacity(0.1))
                            }
                        }
                    }
                    .frame(minHeight: 100)
                }
            }
            .frame(minWidth: 500, minHeight: 400) // Increased width for better button layout
            
            Divider()
            
            // Footer Actions
            HStack {
                // Language Controls
                HStack(spacing: 8) {
                    Picker("", selection: $sourceLanguage) {
                        Text("Auto").tag("Auto")
                        ForEach(SettingsManager.shared.translationLanguages, id: \.self) { lang in
                            Text(lang).tag(lang)
                        }
                    }
                    .frame(width: 100)
                    
                    Image(systemName: "arrow.right").font(.caption)
                    
                    Picker("", selection: $targetLanguage) {
                        ForEach(SettingsManager.shared.translationLanguages, id: \.self) { lang in
                            Text(lang).tag(lang)
                        }
                    }
                    .frame(width: 100)
                }
                
                Button(action: translateText) {
                    Label("Translate", systemImage: "globe")
                }
                .disabled(isTranslating || text.isEmpty)
                .buttonStyle(.borderedProminent)
                .shadow(color: (!translatedText.isEmpty && text != lastTranslatedInput && SettingsManager.shared.enableAurora) ? .cyan : .clear, radius: 5)
                .scaleEffect((!translatedText.isEmpty && text != lastTranslatedInput) ? 1.05 : 1.0)
                .animation(.easeInOut(duration: 0.3), value: text)
                
                Spacer()
                
                // Copy Buttons
                HStack(spacing: 12) {
                    Button(action: { copyText(text, target: .original) }) {
                        Text("Copy Original")
                    }
                    
                    if !translatedText.isEmpty {
                        Button(action: { copyText(translatedText, target: .translation) }) {
                            Text("Copy Translation")
                        }
                        .buttonStyle(.borderedProminent) // Highlight result copy
                    }
                }
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(minWidth: 650, minHeight: 500)
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .alert("Long Text Detected", isPresented: $showLengthWarning) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("The extracted text is over 2000 characters via Apple Vision.\nTranslation might take longer than usual.")
        }
        .onAppear {
            if text.count > 2000 {
                showLengthWarning = true
            }
            // Auto-detect language just for UI
            let detected = AIHelper.shared.detectLanguage(text: text)
            if detected != "Undetermined" {
                // We don't change 'sourceLanguage' to detected, we keep it 'Auto',
                // but we could show it in UI if we wanted.
                // Or we can set it:
                // sourceLanguage = detected
            }
        }
    }
    
    enum CopyTarget {
        case original, translation, none
    }
    
    @State private var showCopyFlash = false
    @State private var activeCopyTarget: CopyTarget = .none
    
    func copyText(_ text: String, target: CopyTarget) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        // Animation if enabled
        if SettingsManager.shared.enableAurora {
            activeCopyTarget = target
            withAnimation(.easeIn(duration: 0.1)) {
                showCopyFlash = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeOut(duration: 0.5)) {
                    showCopyFlash = false
                }
            }
        }
    }
    
    func getStats(_ text: String) -> String {
        let charCount = text.count
        let wordCount = text.split { $0.isWhitespace || $0.isNewline }.count
        return "\(wordCount) words, \(charCount) chars"
    }
    
    var computedTextColor: NSColor {
        switch bgMode {
        case "Dark": return .white
        case "Light": return .black
        case "Custom":
            // Simple brightness check for custom color
            if let color = Color(hex: customColorHex),
               let nsColor = NSColor(color).usingColorSpace(.sRGB) {
                return nsColor.brightnessComponent > 0.5 ? .black : .white
            }
            return .textColor
        default: return .textColor
        }
    }

    func translateText() {
        isTranslating = true
        // Pass source and target
        AIHelper.shared.translateWithOllama(text: text, from: sourceLanguage, to: targetLanguage) { result in
            DispatchQueue.main.async {
                isTranslating = false
                switch result {
                case .success(let translated):
                    self.translatedText = translated
                    self.lastTranslatedInput = self.text
                    HistoryManager.shared.addEntry(
                        original: self.text, 
                        translated: translated, 
                        source: self.sourceLanguage, 
                        target: self.targetLanguage
                    )
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    self.showError = true
                }
            }
        }
    }

    func shareContent() {
        let textToShare = text
        let items = [textToShare] as [Any]
        let picker = NSSharingServicePicker(items: items)
        
        if let window = NSApp.windows.first(where: { $0.isKeyWindow }),
           let contentView = window.contentView {
            picker.show(relativeTo: NSRect(x: contentView.bounds.midX, y: 0, width: 0, height: 0), of: contentView, preferredEdge: .minY)
        }
    }
}

class OCRResultWindowController: NSWindowController {
    
    convenience init(text: String) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "OCR Editor"
        window.center()
        window.isReleasedWhenClosed = false
        window.level = .normal
        
        self.init(window: window)
        
        let view = OCRResultView(text: text) { [weak self] in
            self?.close()
        }
        
        window.contentView = NSHostingView(rootView: view)
    }
    func updateText(_ newText: String) {
        let view = OCRResultView(text: newText) { [weak self] in
            self?.close()
        }
        self.window?.contentView = NSHostingView(rootView: view)
    }
}

extension View {
    @ViewBuilder
    func transparentScrolling() -> some View {
        if #available(macOS 13.0, *) {
            self.scrollContentBackground(.hidden)
        } else {
            self
        }
    }
}
