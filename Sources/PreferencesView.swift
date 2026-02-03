// This program was developed by Levko Kravchuk with the help of Vibe Coding
import SwiftUI
import AppKit

struct PreferencesView: View {
    @State private var selectedTab = "general"
    
    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag("general")
            
            AppearanceSettingsView()
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }
                .tag("appearance")
                
            AISettingsView()
                .tabItem {
                    Label("AI", systemImage: "brain.head.profile")
                }
                .tag("ai")
            
            ShortcutsSettingsView()
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }
                .tag("shortcuts")
                
            StampsSettingsView()
                .tabItem {
                    Label("Stamps", systemImage: "seal")
                }
                .tag("stamps")
            
            VersionView()
                .tabItem {
                    Label("Version", systemImage: "info.circle")
                }
                .tag("version")
        }
        .padding(20)
        .frame(width: 600, height: 400)
    }
}

struct GeneralSettingsView: View {
    @ObservedObject var settings = SettingsManager.shared
    
    var body: some View {
        Form {
            Section(header: Text("Save Location")) {
                HStack {
                    Text(settings.saveDirectory.path)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    
                    Button("Choose...") {
                        settings.promptForSaveDirectory()
                    }
                }
            }
            
            Section(header: Text("Overlay Behavior")) {
                Toggle("Blur Background", isOn: $settings.blurBackground)
                if settings.blurBackground {
                    Slider(value: $settings.blurAmount, in: 0...20) {
                        Text("Blur Amount")
                    }
                }
                
                Text("Turning off blur will dim the background instead.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

struct AppearanceSettingsView: View {
    @ObservedObject var settings = SettingsManager.shared
    
    var body: some View {
        Form {
            Section(header: Text("Aurora Glow Effect")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Glow Coverage: \(Int(settings.auroraGlowSize)) px")
                    
                    Slider(value: $settings.auroraGlowSize, in: 5...50, step: 1) {
                        Text("Glow Size")
                    }
                    
                    Text("Controls how far the aurora glow extends beyond the selection area.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Section(header: Text("Theme")) {
                Text("Aurora Screenshot follows system appearance (Dark/Light).")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

struct AISettingsView: View {
    @AppStorage("AIPrompt") private var prompt = ""
    @AppStorage("AIApiKey") private var apiKey = ""
    @AppStorage("EnableOllama") private var enableOllama = false
    @AppStorage("OllamaHost") private var ollamaHost = "http://localhost:11434"
    @AppStorage("OllamaModel") private var ollamaModel = "llava"
    @AppStorage("OllamaTranslationModel") private var ollamaTranslationModel = "llama3.1"
    @AppStorage("ProxyServer") private var proxyServer = ""
    @AppStorage("MaxImageSizeKB") private var maxImageSizeKB = 5000
    @AppStorage("MaxTranslationSizeKB") private var maxTranslationSizeKB = 500
    
    @State private var newLanguage: String = ""
    @State private var defaultTargetLang: String = SettingsManager.shared.defaultTargetLanguage
    @State private var languages: [String] = SettingsManager.shared.translationLanguages
    
    var body: some View {
        Form {
            Section(header: Text("AI Configuration")) {
                SecureField("API Key (OpenAI)", text: $apiKey)
                
                Text("Custom Prompt:")
                TextEditor(text: $prompt)
                    .frame(height: 60)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.5), lineWidth: 1))
            }
            
            Section(header: Text("Ollama Local AI")) {
                Toggle("Enable Ollama Integration", isOn: $enableOllama)
                
                if enableOllama {
                    TextField("Ollama Host", text: $ollamaHost)
                    
                    // Models Section
                    Group {
                        HStack {
                            Text("Image Model:")
                                .frame(width: 130, alignment: .leading)
                            TextField("e.g. llava", text: $ollamaModel)
                        }
                        
                        HStack {
                            Text("Translation Model:")
                                .frame(width: 130, alignment: .leading)
                            TextField("e.g. llama3.1", text: $ollamaTranslationModel)
                        }
                    }
                    
                    Divider()
                    
                    // Size Limits Section
                    Text("Size Limits (KB):")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text("Max Image Size:")
                            .frame(width: 130, alignment: .leading)
                        TextField("KB", value: $maxImageSizeKB, format: .number)
                            .frame(width: 80)
                        Text("KB")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Max Translation:")
                            .frame(width: 130, alignment: .leading)
                        TextField("KB", value: $maxTranslationSizeKB, format: .number)
                            .frame(width: 80)
                        Text("KB")
                            .foregroundColor(.secondary)
                    }
                    
                    Text("Limits protect against memory exhaustion.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
             Section(header: Text("Network")) {
                TextField("Proxy Server (Optional)", text: $proxyServer)
            }
            
            Section(header: Text("Translation Config")) {
                 Text("Available Languages:")
                 
                 ForEach(languages, id: \.self) { lang in
                     HStack {
                         Text(lang)
                             .frame(maxWidth: .infinity, alignment: .leading)
                         
                         Image(systemName: "trash")
                             .foregroundColor(.red)
                             .onTapGesture {
                                 removeLanguage(lang)
                             }
                     }
                     .padding(.vertical, 2)
                 }
                 .frame(height: min(CGFloat(languages.count * 24), 150))
                 
                 HStack {
                     TextField("Add Language (e.g. Japanese)", text: $newLanguage)
                     Button(action: {
                         if !newLanguage.isEmpty && !languages.contains(newLanguage) {
                             languages.append(newLanguage)
                             SettingsManager.shared.translationLanguages = languages
                             newLanguage = ""
                         }
                     }) {
                         Image(systemName: "plus.circle.fill")
                     }
                     .disabled(newLanguage.isEmpty)
                 }
                 
                 Picker("Default Target Language:", selection: $defaultTargetLang) {
                     ForEach(languages, id: \.self) { lang in
                         Text(lang).tag(lang)
                     }
                 }
                 .onChange(of: defaultTargetLang) { newValue in
                     SettingsManager.shared.defaultTargetLanguage = newValue
                     SettingsManager.shared.targetLanguage = newValue
                 }
            }
        }
        .padding()
        .onAppear {
            defaultTargetLang = SettingsManager.shared.defaultTargetLanguage
        }
    }
    
    func removeLanguage(_ lang: String) {
        if let idx = languages.firstIndex(of: lang) {
            languages.remove(at: idx)
            SettingsManager.shared.translationLanguages = languages
        }
    }
}

struct ShortcutsSettingsView: View {
    @ObservedObject var settings = SettingsManager.shared
    
    var body: some View {
        Form {
            Section(header: Text("Global Shortcuts")) {
                ShortcutRecorderRow(label: "Take Screenshot", shortcut: $settings.shortcut) { new in
                    settings.shortcut = new
                    NotificationCenter.default.post(name: Notification.Name("HotkeyChanged"), object: nil)
                }
                
                ShortcutRecorderRow(label: "Quick OCR", shortcut: $settings.ocrShortcut) { new in
                    settings.ocrShortcut = new
                    NotificationCenter.default.post(name: Notification.Name("HotkeyChanged"), object: nil)
                }
                
                ShortcutRecorderRow(label: "Repeat Selection", shortcut: $settings.repeatShortcut) { new in
                    settings.repeatShortcut = new
                    NotificationCenter.default.post(name: Notification.Name("HotkeyChanged"), object: nil)
                }
                
                ShortcutRecorderRow(label: "Cancel Capture", shortcut: $settings.cancelShortcut) { new in
                    settings.cancelShortcut = new
                    NotificationCenter.default.post(name: Notification.Name("HotkeyChanged"), object: nil)
                }
            }
        }
        .padding()
    }
}

// Updated Robust Recorder from Phase 43
struct ShortcutRecorderRow: View {
    let label: String
    @Binding var shortcut: Shortcut
    var onChange: (Shortcut) -> Void
    @State private var isRecording = false
    
    // State object to hold the monitor to prevent closure capture cycle issues
    @State private var monitor: Any?
    
    var body: some View {
        HStack {
            Text(label)
                .frame(width: 120, alignment: .leading)
            
            HStack {
                Text(isRecording ? "Press keys..." : shortcut.description)
                    .font(.system(size: 14, weight: .bold))
                    .frame(minWidth: 100, minHeight: 24)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(isRecording ? Color.accentColor : Color.secondary, lineWidth: 1)
                    )
                
                Button(isRecording ? "Cancel" : "Record") {
                    toggleRecording()
                }
            }
            
            if isRecording {
                Text("ESC to cancel")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
        .onDisappear {
            stopRecording()
        }
    }
    
    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    func startRecording() {
        isRecording = true
        // Add Local Monitor
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { // ESC
                stopRecording()
                return nil
            }
            
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            // Ignore just modifier key presses for now, wait for a key? 
            // Or allow modifiers triggers? Usually we want Key+Mods.
            // But let's accept it if it's not just a modifier key code.
            
            let sc = Shortcut(keyCode: event.keyCode, modifierFlags: flags.rawValue)
            self.shortcut = sc
            self.onChange(sc)
            stopRecording()
            
            return nil // Consume event
        }
    }
    
    func stopRecording() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        isRecording = false
    }
}

struct StampsSettingsView: View {
    @ObservedObject var settings = SettingsManager.shared
    
    var body: some View {
        Form {
            Section(header: Text("Timestamp")) {
                Toggle("Add Timestamp", isOn: $settings.showTimestamp)
                
                // Formats: US, EU, US+Sec, EU+Sec, ISO, Asia
                Picker("Format:", selection: $settings.timestampFormat) {
                    Text("US (MM/dd HH:mm)").tag("US")
                    Text("EU (dd/MM HH:mm)").tag("EU")
                    Text("US + Seconds").tag("US_SEC")
                    Text("EU + Seconds").tag("EU_SEC")
                    Text("ISO 8601 (yyyy-MM-dd)").tag("ISO")
                    Text("Asia (yyyy/MM/dd)").tag("ASIA")
                }
            }
            
            Section(header: Text("Watermark")) {
                Toggle("Add Watermark", isOn: $settings.showWatermark)
                TextField("Text", text: $settings.watermarkText)
                Slider(value: $settings.watermarkSize, in: 10...100) {
                    Text("Size: \(Int(settings.watermarkSize)) pt")
                }
            }
        }
        .padding()
    }
}

struct VersionView: View {
    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    
    var body: some View {
        VStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 128, height: 128)
            
            Text("Aurora Screenshot")
                .font(.title)
                .bold()
                .foregroundStyle(
                    LinearGradient(
                        colors: [.cyan, .green, .purple, .pink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            Text("Version \(version) (Build \(build))")
                .foregroundColor(.secondary)
            
            Divider()
                .frame(width: 200)
            
            Text("Created by Levko Kravchuk")
                .font(.caption)
            
            Link("levko.kravchuk.net.ua", destination: URL(string: "https://levko.kravchuk.net.ua")!)
                .font(.caption)
                .foregroundColor(.accentColor)
            
            Spacer()
        }
        .padding(.top, 20)
    }
}
