// This program was developed by Levko Kravchuk with the help of Vibe Coding
import SwiftUI
import Cocoa

struct PreferencesView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
            AppearanceSettingsView()
                .tabItem {
                    Label("Appearance", systemImage: "paintpalette")
                }
            AISettingsView()
                .tabItem {
                    Label("AI", systemImage: "brain.head.profile")
                }
            HistorySettingsView()
                .tabItem {
                    Label("History", systemImage: "clock")
                }
            ShortcutsSettingsView()
                .tabItem {
                    Label("Miscellaneous", systemImage: "keyboard")
                }
            StampSettingsView()
                .tabItem {
                    Label("Stamps", systemImage: "seal")
                }
            AboutSettingsView()
                .tabItem {
                    Label("Version", systemImage: "info.circle")
                }
        }
        .frame(minWidth: 900, maxWidth: .infinity, minHeight: 500, maxHeight: .infinity)
        .padding()
    }
}



struct AppearanceSettingsView: View {
    @State private var blurBackground = SettingsManager.shared.blurBackground
    @State private var blurAmount = SettingsManager.shared.blurAmount
    @State private var enableAurora = SettingsManager.shared.enableAurora
    @State private var auroraIntensity = SettingsManager.shared.auroraIntensity
    @State private var auroraGlowSize = SettingsManager.shared.auroraGlowSize
    
    @State private var ocrFontSize = SettingsManager.shared.ocrFontSize
    @State private var ocrBgMode = SettingsManager.shared.ocrEditorBgMode
    @State private var ocrCustomColor = Color.black
    
    var body: some View {
        Form {
            Section(header: Text("Overlay Blur")) {
                Toggle("Blur Inactive Area", isOn: $blurBackground)
                    .onChange(of: blurBackground) { newValue in
                        SettingsManager.shared.blurBackground = newValue
                    }
                
                if blurBackground {
                    HStack {
                        Text("Amount:")
                        Slider(value: $blurAmount, in: 1...20)
                            .onChange(of: blurAmount) { newValue in
                                SettingsManager.shared.blurAmount = newValue
                            }
                        Text("\(Int(blurAmount))%")
                    }
                    
                    Text("⚠️ Blur may increase memory usage during capture")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            Divider()
            
            Section(header: Text("Aurora Effect 🌌")) {
                Toggle("Enable Aurora Effect", isOn: $enableAurora)
                    .help("Show a Northern Lights glow around the selection")
                    .toggleStyle(SwitchToggleStyle(tint: .cyan)) // Aurora Cyan tint
                    .onChange(of: enableAurora) { newValue in
                        SettingsManager.shared.enableAurora = newValue
                    }
                
                if enableAurora {
                    HStack {
                        Text("Intensity:")
                        Slider(value: $auroraIntensity, in: 0.5...2.0)
                            .accentColor(.purple) // Aurora Purple
                            .onChange(of: auroraIntensity) { newValue in
                                SettingsManager.shared.auroraIntensity = newValue
                            }
                        Text(String(format: "%.1fx", auroraIntensity))
                            .foregroundColor(.purple)
                    }
                    
                    HStack {
                        Text("Glow Size:")
                        Slider(value: $auroraGlowSize, in: 5...50, step: 1)
                            .accentColor(.teal) // Aurora Teal/Green
                            .onChange(of: auroraGlowSize) { newValue in
                                SettingsManager.shared.auroraGlowSize = newValue
                            }
                        Text("\(Int(auroraGlowSize)) px")
                            .foregroundColor(.teal)
                    }
                    
                    Text("Glow Size controls how far the aurora extends beyond the selection.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Section(header: Text("OCR Editor Appearance")) {
                HStack {
                    Text("Font Size:")
                    Slider(value: $ocrFontSize, in: 10...32, step: 1)
                        .onChange(of: ocrFontSize) { val in
                            SettingsManager.shared.ocrFontSize = val
                        }
                    Text("\(Int(ocrFontSize)) pt")
                }
                
                Picker("Background:", selection: $ocrBgMode) {
                    Text("System Default").tag("System")
                    Text("Dark").tag("Dark")
                    Text("Light").tag("Light")
                    Text("Custom Color").tag("Custom")
                }
                .onChange(of: ocrBgMode) { val in
                    SettingsManager.shared.ocrEditorBgMode = val
                }
                
                if ocrBgMode == "Custom" {
                    ColorPicker("Custom Background", selection: $ocrCustomColor)
                        .onChange(of: ocrCustomColor) { val in
                            SettingsManager.shared.ocrEditorCustomColor = val.toHex() ?? "#1E1E1E"
                        }
                }
            }
        }
        .padding()
        .onAppear {
            blurBackground = SettingsManager.shared.blurBackground
            blurAmount = SettingsManager.shared.blurAmount
            enableAurora = SettingsManager.shared.enableAurora
            auroraIntensity = SettingsManager.shared.auroraIntensity
            auroraGlowSize = SettingsManager.shared.auroraGlowSize
            
            ocrFontSize = SettingsManager.shared.ocrFontSize
            ocrBgMode = SettingsManager.shared.ocrEditorBgMode
            if let col = Color(hex: SettingsManager.shared.ocrEditorCustomColor) {
               ocrCustomColor = col
            }
        }
    }
}

struct AISettingsView: View {
    @State private var apiKey = SettingsManager.shared.aiApiKey
    @State private var prompt = SettingsManager.shared.aiPrompt
    @State private var enableOllama = SettingsManager.shared.enableOllama
    @State private var ollamaHost = SettingsManager.shared.ollamaHost
    @State private var ollamaModel = SettingsManager.shared.ollamaModel
    @State private var ollamaTranslationModel = SettingsManager.shared.ollamaTranslationModel
    @State private var maxImageSizeKB = SettingsManager.shared.maxImageSizeKB
    @State private var maxTranslationSizeKB = SettingsManager.shared.maxTranslationSizeKB
    @State private var languages: [String] = SettingsManager.shared.translationLanguages
    @State private var newLanguage: String = "" // Added missing state
    @State private var defaultTargetLang: String = SettingsManager.shared.defaultTargetLanguage
    
    var body: some View {
        Form {
            // BETA Warning Banner
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("BETA")
                        .font(.headline.bold())
                        .foregroundColor(.orange)
                    Spacer()
                }
                Text("AI features are in beta. Some settings may not work as expected.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(10)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(8)
            .padding(.bottom, 8)
            
            Section(header: Text("AI Configuration")) {
                TextField("API Key", text: $apiKey)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onChange(of: apiKey) { newValue in
                        SettingsManager.shared.aiApiKey = newValue
                    }
                
                Text("Custom Prompt:")
                TextEditor(text: $prompt)
                    .frame(height: 50)
                    .border(Color.secondary.opacity(0.2))
                    .onChange(of: prompt) { newValue in
                        SettingsManager.shared.aiPrompt = newValue
                    }
            }
            
            Section(header: Text("Ollama Local AI")) {
                Toggle("Enable Ollama Integration", isOn: $enableOllama)
                    .onChange(of: enableOllama) { newValue in
                        SettingsManager.shared.enableOllama = newValue
                    }
                
                if enableOllama {
                    TextField("Host URL", text: $ollamaHost)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onChange(of: ollamaHost) { newValue in
                            SettingsManager.shared.ollamaHost = newValue
                        }
                    
                    // Models Section - Fixed Alignment
                    // Models Section - Fixed Alignment (VStack fallback)
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Image Model:")
                                .frame(width: 130, alignment: .leading)
                            TextField("e.g. llava", text: $ollamaModel)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .onChange(of: ollamaModel) { newValue in
                                    SettingsManager.shared.ollamaModel = newValue
                                }
                        }
                        
                        HStack {
                            Text("Trans. Model:")
                                .frame(width: 130, alignment: .leading)
                            TextField("e.g. llama3.1", text: $ollamaTranslationModel)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .onChange(of: ollamaTranslationModel) { newValue in
                                    SettingsManager.shared.ollamaTranslationModel = newValue
                                }
                        }
                    }
                    
                    Divider()
                    
                    // Size Limits
                    Text("Size Limits (KB):")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Max Image:")
                                .frame(width: 130, alignment: .leading)
                            HStack {
                                TextField("KB", value: $maxImageSizeKB, format: .number)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .frame(width: 80)
                                    .onChange(of: maxImageSizeKB) { newValue in
                                        SettingsManager.shared.maxImageSizeKB = newValue
                                    }
                                Text("KB").foregroundColor(.secondary)
                            }
                        }
                        HStack {
                            Text("Max Trans:")
                                .frame(width: 130, alignment: .leading)
                            HStack {
                                TextField("KB", value: $maxTranslationSizeKB, format: .number)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .frame(width: 80)
                                    .onChange(of: maxTranslationSizeKB) { newValue in
                                        SettingsManager.shared.maxTranslationSizeKB = newValue
                                    }
                                Text("KB").foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Text("Use llava for images, llama3.1/mistral for translation.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
             Section(header: Text("Translation Config")) {
                 Text("Available Languages:")
                 
                 ForEach(languages, id: \.self) { lang in
                     HStack {
                         Text(lang)
                         Spacer()
                         Button(action: {
                             if let idx = languages.firstIndex(of: lang) {
                                 languages.remove(at: idx)
                                 SettingsManager.shared.translationLanguages = languages
                             }
                         }) {
                             Image(systemName: "trash")
                                 .foregroundColor(.red)
                         }
                         .buttonStyle(.plain)
                     }
                 }
                 
                 HStack {
                     TextField("Add Language (e.g. Japanese)", text: $newLanguage)
                         .textFieldStyle(RoundedBorderTextFieldStyle())
                     
                     Button(action: {
                         if !newLanguage.isEmpty {
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
                     ForEach(SettingsManager.shared.translationLanguages, id: \.self) { lang in
                         Text(lang).tag(lang)
                     }
                 }
                 .onChange(of: defaultTargetLang) { newValue in
                     SettingsManager.shared.defaultTargetLanguage = newValue
                     SettingsManager.shared.targetLanguage = newValue // Sync legacy key if needed
                 }
            }
        }
        .padding()
        .onAppear {
            apiKey = SettingsManager.shared.aiApiKey
            prompt = SettingsManager.shared.aiPrompt
            enableOllama = SettingsManager.shared.enableOllama
            ollamaHost = SettingsManager.shared.ollamaHost
            ollamaModel = SettingsManager.shared.ollamaModel
            defaultTargetLang = SettingsManager.shared.defaultTargetLanguage
        }
    }
}


struct GeneralSettingsView: View {
    @State private var path: String = SettingsManager.shared.saveDirectory.path
    @State private var launchAtLogin = SettingsManager.shared.launchAtLogin
    @State private var downscaleRetina = SettingsManager.shared.downscaleRetina
    @AppStorage("showTranslateButton") private var showTranslateButton = true // Merged
    
    var body: some View {
        Form {
            Section(header: Text("Toolbar")) {
                 Toggle("Show Translate Button", isOn: $showTranslateButton)
                     .help("Show the Translate button in the screenshot toolbar")
                     .onChange(of: showTranslateButton) { newValue in
                         SettingsManager.shared.showTranslateButton = newValue
                     }
            }
            
            Section(header: Text("Save Location")) {
                HStack {
                    Text(path)
                        .truncationMode(.middle)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Button("Change...") {
                        SettingsManager.shared.promptForSaveDirectory()
                        path = SettingsManager.shared.saveDirectory.path
                    }
                }
            }
            
            Section(header: Text("System")) {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        SettingsManager.shared.launchAtLogin = newValue
                    }
            }
            
            Section(header: Text("Capture")) {
                Toggle("Downscale Retina screens (2x -> 1x)", isOn: $downscaleRetina)
                    .onChange(of: downscaleRetina) { newValue in
                        SettingsManager.shared.downscaleRetina = newValue
                    }
                Text("Reduces image dimensions by 50% to save space.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .onAppear {
            path = SettingsManager.shared.saveDirectory.path
            launchAtLogin = SettingsManager.shared.launchAtLogin
            downscaleRetina = SettingsManager.shared.downscaleRetina
        }
    }
}

struct ShortcutsSettingsView: View {
    @State private var screenshotShortcut = SettingsManager.shared.shortcut
    @State private var ocrShortcut = SettingsManager.shared.ocrShortcut
    @State private var settingsShortcut = SettingsManager.shared.settingsShortcut
    @State private var translationShortcut = Shortcut(keyCode: 17, modifierFlags: NSEvent.ModifierFlags.option.rawValue) // Default T+Option

    @State private var repeatShortcut = SettingsManager.shared.repeatShortcut
    @State private var cancelShortcut = SettingsManager.shared.cancelShortcut
    
    var body: some View {
        Form {
            Section(header: Text("Global Shortcuts")) {
                ShortcutRecorderRow(label: "Take Screenshot", shortcut: $screenshotShortcut) { new in
                    SettingsManager.shared.shortcut = new
                    NotificationCenter.default.post(name: Notification.Name("HotkeyChanged"), object: nil)
                }
                
                ShortcutRecorderRow(label: "Quick OCR", shortcut: $ocrShortcut) { new in
                    SettingsManager.shared.ocrShortcut = new
                    NotificationCenter.default.post(name: Notification.Name("HotkeyChanged"), object: nil)
                }
                
                ShortcutRecorderRow(label: "Translation Mode", shortcut: $translationShortcut) { new in
                    SettingsManager.shared.saveHotKey(key: "translationHotkey", keyCode: Int(new.keyCode), modifiers: new.modifierFlags, enable: true)
                    NotificationCenter.default.post(name: Notification.Name("HotkeyChanged"), object: nil)
                }
                
                ShortcutRecorderRow(label: "Open Menu", shortcut: $settingsShortcut) { new in
                    SettingsManager.shared.settingsShortcut = new
                    NotificationCenter.default.post(name: Notification.Name("HotkeyChanged"), object: nil)
                }
            }
            
            Section(header: Text("In-Overlay Shortcuts")) {
                ShortcutRecorderRow(label: "Repeat Last", shortcut: $repeatShortcut) { new in
                    SettingsManager.shared.repeatShortcut = new
                    NotificationCenter.default.post(name: Notification.Name("HotkeyChanged"), object: nil)
                }
                
                ShortcutRecorderRow(label: "Cancel Selection", shortcut: $cancelShortcut) { new in
                    SettingsManager.shared.cancelShortcut = new
                    NotificationCenter.default.post(name: Notification.Name("HotkeyChanged"), object: nil)
                }
            }
        }
        .padding()
        .onAppear {
             let t = SettingsManager.shared.translationHotKey
             translationShortcut = Shortcut(keyCode: UInt16(t.0), modifierFlags: t.1)
        }
    }
}

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
            
            // Allow purely function keys? Yes.
            
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

struct StampSettingsView: View {
    @State private var showTimestamp = SettingsManager.shared.showTimestamp
    @State private var timestampFormat = SettingsManager.shared.timestampFormat
    @State private var showWatermark = SettingsManager.shared.showWatermark
    @State private var watermarkText = SettingsManager.shared.watermarkText
    @State private var watermarkSize = SettingsManager.shared.watermarkSize
    
    var body: some View {
        Form {
            Section(header: Text("Timestamp")) {
                Toggle("Add Timestamp", isOn: $showTimestamp)
                    .onChange(of: showTimestamp) { newValue in
                        SettingsManager.shared.showTimestamp = newValue
                    }
                
                if showTimestamp {
                    Picker("Format", selection: $timestampFormat) {
                        Text("US (MM/dd HH:mm)").tag("US")
                        Text("EU (dd/MM HH:mm)").tag("EU")
                        Text("US + Seconds").tag("US_SEC")
                        Text("EU + Seconds").tag("EU_SEC")
                        Text("ISO 8601 (yyyy-MM-dd)").tag("ISO")
                        Text("Asia (yyyy/MM/dd)").tag("ASIA")
                    }
                    .onChange(of: timestampFormat) { newValue in
                        SettingsManager.shared.timestampFormat = newValue
                    }
                    Text("Color uses selected brush color.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Section(header: Text("Watermark")) {
                Toggle("Add Watermark", isOn: $showWatermark)
                    .onChange(of: showWatermark) { newValue in
                        SettingsManager.shared.showWatermark = newValue
                    }
                
                if showWatermark {
                    TextField("Text", text: $watermarkText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onChange(of: watermarkText) { newValue in
                            SettingsManager.shared.watermarkText = newValue
                        }
                    
                    HStack {
                        Text("Size:")
                        Slider(value: $watermarkSize, in: 10...100)
                            .onChange(of: watermarkSize) { newValue in
                                SettingsManager.shared.watermarkSize = newValue
                            }
                        Text("\(Int(watermarkSize)) pt")
                            .frame(width: 40, alignment: .trailing)
                    }
                }
            }
        }
        .padding()
        .onAppear {
            showTimestamp = SettingsManager.shared.showTimestamp
            timestampFormat = SettingsManager.shared.timestampFormat
            showWatermark = SettingsManager.shared.showWatermark
            watermarkSize = SettingsManager.shared.watermarkSize
        }
    }
}

struct AnimatedLogoText: View {
    @State private var hueRotation: Double = 0
    
    var body: some View {
        HStack(spacing: 4) {
            Text("Aurora Screen Shot")
                .foregroundStyle(
                    LinearGradient(
                        colors: [.cyan, .green, .purple, .pink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .hueRotation(.degrees(hueRotation))
            
            Text("🇨🇦") // Flag outside gradient to keep colors
        }
        .font(.title.bold())
        .onAppear {
            withAnimation(.linear(duration: 5.0).repeatForever(autoreverses: true)) {
                hueRotation = 360
            }
        }
    }
}

struct AboutSettingsView: View {
    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    
    @State private var updateFrequency = SettingsManager.shared.updateFrequency
    @State private var proxyServer = SettingsManager.shared.proxyServer
    @State private var repoUrl = SettingsManager.shared.repositoryURL
    @State private var autoRestart = SettingsManager.shared.autoRestartAfterUpdate
    @State private var autoCheckUpdates = SettingsManager.shared.autoCheckUpdates
    
    @State private var showUpdateAlert = false
    @State private var updateMessage = ""
    
    let frequencies = ["Daily", "Weekly", "Monthly"]
    
    var body: some View {
        Form {
            Section {
                HStack(spacing: 15) {
                    if let icon = NSImage(named: NSImage.applicationIconName) {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 64, height: 64)
                    } else {
                        Image(systemName: "text.viewfinder")
                            .font(.system(size: 64))
                            .foregroundColor(.accentColor)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        AnimatedLogoText() // Moved to separate view for reliable animation
                        
                        Text("Version \(version) (Build \(build))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            LinearGradient(
                                colors: [.cyan.opacity(0.5), .purple.opacity(0.5), .pink.opacity(0.5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .padding(.horizontal, 8)
            }
            
            Section(header: Text("Updates")) {
                Toggle("Automatically check for updates", isOn: $autoCheckUpdates)
                    .onChange(of: autoCheckUpdates) { newValue in
                        SettingsManager.shared.autoCheckUpdates = newValue
                    }

                Picker("Check for updates:", selection: $updateFrequency) {
                    ForEach(frequencies, id: \.self) { freq in
                        Text(freq)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .onChange(of: updateFrequency) { newValue in
                    SettingsManager.shared.updateFrequency = newValue
                }
                
                Button("Check for Updates") {
                    checkForUpdates(silent: false)
                }
                .alert("Update Available", isPresented: $showUpdateAlert) {
                     if let newVer = newVersionAvailable {
                         Button("Download & Install", role: .none) {
                             downloadAndInstall(version: newVer)
                         }
                         Button("View Changelog", role: .none) {
                             if let url = URL(string: "https://github.com/LEO2008k/AuroraScreenShot/tree/production") {
                                 NSWorkspace.shared.open(url)
                             }
                         }
                         Button("Cancel", role: .cancel) { }
                     } else {
                         Button("OK", role: .cancel) { }
                     }
                } message: {
                    Text(updateMessage)
                }
                
                Toggle("Auto-restart after update", isOn: $autoRestart)
                    .onChange(of: autoRestart) { newValue in
                        SettingsManager.shared.autoRestartAfterUpdate = newValue
                    }
                
                HStack {
                    Text("Update Source:")
                    Text("Official Repository (LEO2008k)")
                        .foregroundColor(.secondary)
                }
                .font(.caption)
            }
            
            Section(header: Text("Network")) {
                TextField("Proxy Server (http://...)", text: $proxyServer)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onChange(of: proxyServer) { newValue in
                        SettingsManager.shared.proxyServer = newValue
                    }
                Text("Leave empty to use system settings")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section(header: Text("Credits & Support")) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Developed by **Levko Kravchuk**")
                    
                    // Styled Link Buttons
                    HStack(spacing: 12) {
                        Link(destination: URL(string: "https://levko.kravchuk.net.ua")!) {
                            HStack {
                                Image(systemName: "globe")
                                Text("Website")
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain) // Make it clickable but customized
                        
                        Link(destination: URL(string: "https://www.patreon.com/posts/meet-aurora-shot-149870544")!) {
                            HStack {
                                Image(systemName: "heart.fill").foregroundColor(.red)
                                Text("Support on Patreon")
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.orange.opacity(0.5), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Feedback Button
                    Link(destination: URL(string: "https://docs.google.com/forms/d/e/1FAIpQLScfmeY8L5rUCBJ9JsP0YHGQb76Rih5vw7AJ7wofX4S-vn4rbQ/viewform")!) {
                        HStack {
                            Image(systemName: "bubble.left.and.exclamationmark.bubble.fill")
                                .foregroundColor(.green)
                            Text("Send Feedback / Feature Request")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.green.opacity(0.5), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    
                    Text("Powered by **Vibe Coding**")
                        .foregroundColor(.secondary)
                        .font(.footnote)
                        .padding(.top, 4)
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .onAppear {
            updateFrequency = SettingsManager.shared.updateFrequency
            proxyServer = SettingsManager.shared.proxyServer
            repoUrl = SettingsManager.shared.repositoryURL
            autoCheckUpdates = SettingsManager.shared.autoCheckUpdates
            
            if autoCheckUpdates {
                checkForUpdates(silent: true)
            }
        }
    }
    @State private var newVersionAvailable: String? = nil

    func checkForUpdates(silent: Bool = false) {
        // Hardcoded URL for official updates
        let urlStr = "https://raw.githubusercontent.com/LEO2008k/AuroraScreenShot/new-features/version.txt"
        
        guard let url = URL(string: urlStr) else {
            if !silent {
                updateMessage = "Invalid URL"
                showUpdateAlert = true
            }
            return
        }
        
        if !silent {
            updateMessage = "Checking for updates..."
        }
        newVersionAvailable = nil
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    if !silent {
                        updateMessage = "Error: \(error.localizedDescription)"
                        showUpdateAlert = true
                    }
                    return
                }
                
                guard let data = data, let versionStr = String(data: data, encoding: .utf8) else {
                    if !silent {
                        updateMessage = "Could not read version data."
                        showUpdateAlert = true
                    }
                    return
                }
                
                let onlineVer = versionStr.trimmingCharacters(in: .whitespacesAndNewlines)
                
                if onlineVer.contains("<html>") || onlineVer.contains("404") {
                     if !silent {
                         updateMessage = "Error: Version file not found on server (404)."
                         showUpdateAlert = true
                     }
                     return
                }
                
                let cleanOnline = onlineVer.replacingOccurrences(of: "v", with: "")
                
                if isNewer(online: cleanOnline, current: version) {
                    newVersionAvailable = cleanOnline
                    updateMessage = "🚀 New version found: v\(cleanOnline)!\nCurrent: v\(version).\n\nWould you like to install it?"
                    showUpdateAlert = true // Always show if new version found
                } else if !silent {
                    if cleanOnline == version {
                        updateMessage = "You have the latest version (v\(version))."
                    } else {
                        updateMessage = "You are using a newer version than the release channel.\n(Local: v\(version), Online: v\(cleanOnline))"
                    }
                    showUpdateAlert = true
                }
            }
        }.resume()
    }
    
    func isNewer(online: String, current: String) -> Bool {
        let cleanOnline = online.replacingOccurrences(of: "v", with: "")
        let cleanCurrent = current.replacingOccurrences(of: "v", with: "")
        return cleanOnline.compare(cleanCurrent, options: .numeric) == .orderedDescending
    }
    
    func downloadAndInstall(version: String) {
        // format: https://github.com/LEO2008k/AuroraScreenShot/releases/download/v2.0.45/AuroraScreenshot_Installer.dmg
        let downloadUrlStr = "https://github.com/LEO2008k/AuroraScreenShot/releases/download/v\(version)/AuroraScreenshot_Installer.dmg"
        
        guard let url = URL(string: downloadUrlStr) else { return }
        
        NSWorkspace.shared.open(url) // Open browser to download .dmg
        
        // Helper logic: If we want to actually download and mount, we need substantial file handling code.
        // For safety and reliability, opening the direct download link is best.
        // It will download to Downloads folder.
        
        // Notify user
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let alert = NSAlert()
            alert.messageText = "Downloading Update..."
            alert.informativeText = "The installer is downloading.\nPlease open the DMG and drag the app to Applications folder to update.\n\nThe app will quit now."
            alert.addButton(withTitle: "Quit & Install")
            alert.runModal()
            NSApp.terminate(nil)
        }
    }
}

struct HistorySettingsView: View {
    @State private var saveHistory = SettingsManager.shared.saveHistory
    @State private var retentionHours = SettingsManager.shared.historyRetentionHours
    @ObservedObject var manager = HistoryManager.shared
    
    @State private var isCustomMode = false
    
    // Presets for the picker
    let presets = [3, 6, 12, 24, 48, 120, -1]
    
    var body: some View {
        Form {
            Section(header: Text("Privacy & Storage")) {
                Toggle("Enable History Saving", isOn: $saveHistory)
                    .onChange(of: saveHistory) { newValue in
                        SettingsManager.shared.saveHistory = newValue
                    }
                
                if !saveHistory {
                    Text("History is NOT saved. (Recommended for Privacy)")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Text("Translations are saved locally in Application Support.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // File Location
                if let url = manager.historyFileURL {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Storage Path:")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        HStack {
                            Image(systemName: "internaldrive")
                            Text(url.path)
                                .font(.caption2)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .textSelection(.enabled)
                            Spacer()
                            Button("Show") {
                                NSWorkspace.shared.activateFileViewerSelecting([url])
                            }
                            .font(.caption)
                        }
                    }
                    .padding(.top, 4)
                }
            }
            
            if saveHistory {
                Section(header: Text("Retention Policy")) {
                    // Custom Binding for Picker
                    let pickerBinding = Binding<Int>(
                        get: {
                            if isCustomMode { return 0 }
                            if presets.contains(retentionHours) { return retentionHours }
                            return 0 // Default to custom if value is weird
                        },
                        set: { newValue in
                            if newValue == 0 {
                                isCustomMode = true
                                // If switching to custom, keep current hours but enable editing
                            } else {
                                isCustomMode = false
                                retentionHours = newValue
                                SettingsManager.shared.historyRetentionHours = newValue
                                HistoryManager.shared.cleanOldEntries()
                            }
                        }
                    )
                    
                    Picker("Auto-delete history older than:", selection: pickerBinding) {
                        Text("3 Hours").tag(3)
                        Text("6 Hours").tag(6)
                        Text("12 Hours").tag(12)
                        Text("24 Hours").tag(24)
                        Text("48 Hours").tag(48)
                        Text("5 Days").tag(120)
                        Text("Keep Forever").tag(-1)
                        Divider()
                        Text("Custom...").tag(0)
                    }
                    
                    // Show TextField if Custom Mode
                    if isCustomMode {
                        HStack {
                            Text("Custom Retention:")
                            TextField("Hours", value: $retentionHours, format: .number)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 80)
                                .onChange(of: retentionHours) { val in
                                    var safeVal = val
                                    // Constraint: Max 336 hours (2 weeks)
                                    if safeVal > 336 { safeVal = 336 }
                                    // Constraint: Min 1 hour
                                    if safeVal < 1 { safeVal = 1 }
                                    
                                    if safeVal != val { retentionHours = safeVal }
                                    
                                    SettingsManager.shared.historyRetentionHours = safeVal
                                }
                            Text("hours (Max 336)")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if retentionHours > 0 {
                        Text("History older than \(retentionHours) hours will be automatically deleted.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if retentionHours == -1 {
                         Text("Warning: History will grow indefinitely.")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                
                Section(header: Text("Management")) {
                    HStack {
                        Text("Current Items:")
                        Text("\(manager.history.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    Button(action: {
                        HistoryWindowController.shared.show()
                    }) {
                        Label("Open History Window", systemImage: "macwindow")
                    }
                    
                    Button(action: {
                        HistoryManager.shared.clearAll()
                    }) {
                        Label("Clear All History", systemImage: "trash")
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .padding()
        .onAppear {
            saveHistory = SettingsManager.shared.saveHistory
            retentionHours = SettingsManager.shared.historyRetentionHours
            // Determine if custom mode
            if !presets.contains(retentionHours) {
                isCustomMode = true
            } else {
                isCustomMode = false
            }
        }
    }
}


