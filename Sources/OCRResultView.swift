// This program was developed by Levko Kravchuk with the help of Vibe Coding
import SwiftUI
import Cocoa

struct OCRResultView: View {
    @State var text: String
    var onClose: () -> Void
    
    @State private var translatedText: String = ""
    @State private var sourceLanguage: String = "Auto"
    @State private var targetLanguage: String = SettingsManager.shared.defaultTargetLanguage
    @State private var isTranslating = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showLengthWarning = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("OCR Editor")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
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
                         Text("\(text.count) chars")
                             .font(.caption2)
                             .foregroundColor(text.count > 2000 ? .orange : .secondary)
                    }
                    .padding(.horizontal)
                    
                    TextEditor(text: $text)
                        .font(.body)
                        .padding(5)
                        .background(Color(NSColor.controlBackgroundColor))
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
                            Button(action: {
                                let pasteboard = NSPasteboard.general
                                pasteboard.clearContents()
                                pasteboard.setString(translatedText, forType: .string)
                            }) {
                                Image(systemName: "doc.on.doc")
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                            .help("Copy Translation")
                        }
                        .padding(.horizontal)
                        
                        ZStack {
                            TextEditor(text: $translatedText)
                                .font(.body)
                                .padding(5)
                                .background(Color(NSColor.controlBackgroundColor))
                            
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
            .frame(minWidth: 450, minHeight: 400)
            
            Divider()
            
            // Footer Actions
            HStack {
                // Language Controls
                HStack(spacing: 8) {
                    Text("From:")
                        .font(.caption)
                    Picker("", selection: $sourceLanguage) {
                        Text("Auto").tag("Auto")
                        ForEach(SettingsManager.shared.translationLanguages, id: \.self) { lang in
                            Text(lang).tag(lang)
                        }
                    }
                    .frame(width: 120)
                    
                    Text("To:")
                        .font(.caption)
                    Picker("", selection: $targetLanguage) {
                        ForEach(SettingsManager.shared.translationLanguages, id: \.self) { lang in
                            Text(lang).tag(lang)
                        }
                    }
                    .frame(width: 120)
                }
                
                Button(action: translateText) {
                    Label("Translate", systemImage: "globe")
                }
                .disabled(isTranslating || text.isEmpty)
                
                Spacer()
                
                // Copy Original
                Button(action: copyText) {
                    Label("Copy Original", systemImage: "doc.on.doc")
                }
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(minWidth: 600, minHeight: 500)
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
    
    func copyText() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
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
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    self.showError = true
                }
            }
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
