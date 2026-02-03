// This program was developed by Levko Kravchuk with the help of Vibe Coding
import Cocoa

struct AIHelper {
    static let shared = AIHelper()
    
    struct ChatMessage: Codable {
        let role: String
        let content: String
    }
    
    struct ChatRequest: Codable {
        let model: String
        let messages: [ChatMessage]
        let temperature: Double
    }
    
    struct ChatResponse: Codable {
        struct Choice: Codable {
            let message: ChatMessage
        }
        let choices: [Choice]
    }
    
    func translate(text: String, to language: String, completion: @escaping (Result<String, Error>) -> Void) {
        // If Ollama is enabled, prioritize it? User said "Translate via Llama".
        // But the button calls translateWithOllama explicitly in my new view.
        // However, existing "Translate" calls might use this.
        // I will keep this as OpenAI for legacy/backup or if configured.
        
        let apiKey = SettingsManager.shared.aiApiKey
        guard !apiKey.isEmpty else {
            completion(.failure(NSError(domain: "OCRShot", code: 401, userInfo: [NSLocalizedDescriptionKey: "No API Key provided. Please set it in Preferences."])))
            return
        }
        
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // System Prompt
        let systemPrompt = SettingsManager.shared.aiPrompt.isEmpty ? 
            "You are a helpful translator. Translate the following text into \(language). Output ONLY the translated text, no valid explanations." : 
            SettingsManager.shared.aiPrompt + " Translate to \(language)."
            
        let body = ChatRequest(
            model: "gpt-3.5-turbo",
            messages: [
                ChatMessage(role: "system", content: systemPrompt),
                ChatMessage(role: "user", content: text)
            ],
            temperature: 0.3
        )
        
        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "OCRShot", code: 500, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            do {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorDict = json["error"] as? [String: Any],
                   let message = errorDict["message"] as? String {
                     completion(.failure(NSError(domain: "OCRShot", code: 400, userInfo: [NSLocalizedDescriptionKey: "API Error: \(message)"])))
                     return
                }
                
                let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
                if let content = decoded.choices.first?.message.content {
                    completion(.success(content.trimmingCharacters(in: .whitespacesAndNewlines)))
                } else {
                    completion(.failure(NSError(domain: "OCRShot", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    // Ollama Structures
    struct OllamaRequest: Codable {
        let model: String
        let prompt: String
        let images: [String] // Base64 encoded
        let stream: Bool
    }
    
    struct OllamaResponse: Codable {
        let model: String
        let response: String
        let done: Bool
    }
    
    func analyzeImageWithOllama(image: CGImage, completion: @escaping (Result<String, Error>) -> Void) {
        let host = SettingsManager.shared.ollamaHost
        let model = SettingsManager.shared.ollamaModel
        
        guard let url = URL(string: "\(host)/api/generate") else {
            completion(.failure(NSError(domain: "OCRShot", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid Ollama Host URL"])))
            return
        }
        
        // Convert Image to Base64
        let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        guard let tiff = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let pngData = bitmap.representation(using: NSBitmapImageRep.FileType.png, properties: [:]) else {
            completion(.failure(NSError(domain: "OCRShot", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to process image"])))
            return
        }
        let base64Image = pngData.base64EncodedString()
        
        let body = OllamaRequest(
            model: model,
            prompt: "Describe this image in detail.",
            images: [base64Image],
            stream: false
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Check Proxy
        let proxy = SettingsManager.shared.proxyServer
        
        // Use custom session config for proxy if set
        let session: URLSession
        if !proxy.isEmpty {
             let config = URLSessionConfiguration.default
             config.connectionProxyDictionary = [
                 kCFNetworkProxiesHTTPEnable as AnyHashable: true,
                 kCFNetworkProxiesHTTPProxy: proxy
             ] as? [AnyHashable: Any]
             session = URLSession(configuration: config)
        } else {
            session = URLSession.shared
        }
        
        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            completion(.failure(error))
            return
        }
        
        session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "OCRShot", code: 500, userInfo: [NSLocalizedDescriptionKey: "No data from Ollama"])))
                return
            }
            
            do {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let err = json["error"] as? String {
                     completion(.failure(NSError(domain: "OCRShot", code: 500, userInfo: [NSLocalizedDescriptionKey: "Ollama Error: \(err)"])))
                     return
                }

                let decoded = try JSONDecoder().decode(OllamaResponse.self, from: data)
                completion(.success(decoded.response))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    // MARK: - Security Constants
    private static var lastTranslationTime: Date?
    private static let minTimeBetweenRequests: TimeInterval = 1.0 // Rate limit: 1 req/sec
    
    // Translation via Ollama (uses translation-specific model like llama3.1)
    func translateWithOllama(text: String, to language: String, completion: @escaping (Result<String, Error>) -> Void) {
        
        // === SECURITY CHECKS ===
        
        // Get configurable limits from settings (in KB, convert to bytes)
        let maxInputSize = SettingsManager.shared.maxTranslationSizeKB * 1000
        let maxResponseSize = maxInputSize * 2 // Response can be 2x input
        
        // 1. Input size limit (prevent memory exhaustion)
        guard text.count <= maxInputSize else {
            completion(.failure(NSError(domain: "Aurora", code: 413, userInfo: [
                NSLocalizedDescriptionKey: "Text too large. Maximum \(SettingsManager.shared.maxTranslationSizeKB) KB allowed."
            ])))
            return
        }
        
        // 2. Rate limiting (prevent fuzzing/DoS)
        if let lastTime = AIHelper.lastTranslationTime,
           Date().timeIntervalSince(lastTime) < AIHelper.minTimeBetweenRequests {
            completion(.failure(NSError(domain: "Aurora", code: 429, userInfo: [
                NSLocalizedDescriptionKey: "Too many requests. Please wait a moment."
            ])))
            return
        }
        AIHelper.lastTranslationTime = Date()
        
        // 3. Input sanitization (remove control characters but keep valid text)
        let sanitizedText = text.components(separatedBy: .controlCharacters).joined()
        let sanitizedLanguage = language.components(separatedBy: .controlCharacters).joined()
        
        guard !sanitizedText.isEmpty else {
            completion(.failure(NSError(domain: "Aurora", code: 400, userInfo: [
                NSLocalizedDescriptionKey: "Empty text after sanitization."
            ])))
            return
        }
        
        // === END SECURITY CHECKS ===
        
        let host = SettingsManager.shared.ollamaHost
        let model = SettingsManager.shared.ollamaTranslationModel
        
        guard let url = URL(string: "\(host)/api/generate") else {
            completion(.failure(NSError(domain: "Aurora", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid Ollama Host URL"])))
            return
        }
        
        let prompt = "Translate the following text to \(sanitizedLanguage). Output ONLY the translated text, do not add any explanations or notes. \n\nText: \(sanitizedText)"
        
        let body = OllamaRequest(
            model: model,
            prompt: prompt,
            images: [],
            stream: false
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30 // Reduced timeout for security
        
        let session = URLSession.shared
        
        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            completion(.failure(error))
            return
        }
        
        session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "Aurora", code: 500, userInfo: [NSLocalizedDescriptionKey: "No data from Ollama"])))
                return
            }
            
            // Security: Limit response size (prevent memory exhaustion)
            let maxResponseSize = SettingsManager.shared.maxTranslationSizeKB * 2000 // 2x input limit
            guard data.count <= maxResponseSize else {
                completion(.failure(NSError(domain: "Aurora", code: 413, userInfo: [
                    NSLocalizedDescriptionKey: "Response too large. Possible attack or malformed response."
                ])))
                return
            }
            
            do {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let err = json["error"] as? String {
                     completion(.failure(NSError(domain: "Aurora", code: 500, userInfo: [NSLocalizedDescriptionKey: "Ollama Error: \(err)"])))
                     return
                }

                let decoded = try JSONDecoder().decode(OllamaResponse.self, from: data)
                completion(.success(decoded.response.trimmingCharacters(in: .whitespacesAndNewlines)))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}
