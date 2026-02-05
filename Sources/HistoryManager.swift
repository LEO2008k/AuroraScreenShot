import Foundation

struct HistoryItem: Codable, Identifiable {
    var id = UUID()
    let date: Date
    let originalText: String
    let translatedText: String
    let sourceLanguage: String
    let targetLanguage: String
}

class HistoryManager: ObservableObject {
    static let shared = HistoryManager()
    
    @Published var history: [HistoryItem] = []
    
    private let kFileName = "history.json"
    
    init() {
        loadHistory()
        cleanOldEntries()
    }
    
    var historyFileURL: URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let auroraDir = appSupport.appendingPathComponent("AuroraScreenShot")
        // Ensure dir exists
        try? FileManager.default.createDirectory(at: auroraDir, withIntermediateDirectories: true, attributes: nil)
        return auroraDir.appendingPathComponent(kFileName)
    }
    
    func addEntry(original: String, translated: String, source: String, target: String) {
        guard SettingsManager.shared.saveHistory else { return }
        
        // Avoid duplicate spam (same text translated again within short time)
        if let last = history.first, last.originalText == original, last.translatedText == translated {
            return
        }
        
        let item = HistoryItem(date: Date(), originalText: original, translatedText: translated, sourceLanguage: source, targetLanguage: target)
        // Add to top
        history.insert(item, at: 0)
        saveHistory()
    }
    
    func loadHistory() {
        guard let url = historyFileURL, let data = try? Data(contentsOf: url) else { return }
        if let items = try? JSONDecoder().decode([HistoryItem].self, from: data) {
            self.history = items
        }
    }
    
    func saveHistory() {
        guard let url = historyFileURL else { return }
        // JSONEncoder with pretty print for user readability
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        
        if let data = try? encoder.encode(history) {
            try? data.write(to: url)
        }
    }
    
    func clearAll() {
        history.removeAll()
        saveHistory()
    }
    
    func cleanOldEntries() {
        let hours = SettingsManager.shared.historyRetentionHours
        
        // Safety Clean: Enforce Max 2 weeks (336 hours) if user tries to go crazy custom
        // Unless set to -1 (Never), but user said "not more than 2 weeks"
        // Let's respect the user's setting but clamp 'Custom' input in UI. 
        // Here we just apply what is set.
        
        if hours > 0 {
            let cutoff = Date().addingTimeInterval(-Double(hours) * 3600)
            history.removeAll { $0.date < cutoff }
        }
        
        // RAM/Disk Safety: Max 5,000 items
        // Even if time is "Never", we don't want 1GB JSON.
        if history.count > 5000 {
            // Keep the newest 5000
            history = Array(history.prefix(5000))
        }
        
        saveHistory()
    }
}
