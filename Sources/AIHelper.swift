// This program was developed by Levko Kravchuk with the help of Vibe Coding
import Cocoa
import Vision
import NaturalLanguage

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
    
    func translateText(_ text: String, to language: String, completion: @escaping (Result<String, Error>) -> Void) {
        if SettingsManager.shared.enableOllama {
            translateWithOllama(text: text, to: language, completion: completion)
        } else {
            translate(text: text, to: language, completion: completion)
        }
    }

    func translate(text: String, to language: String, completion: @escaping (Result<String, Error>) -> Void) {
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
    
    func analyzeImageWithOllama(image: CGImage, customPrompt: String? = nil, completion: @escaping (Result<String, Error>) -> Void) {
        // STRATEGY CHANGE:
        // If the user hasn't provided a custom prompt (meaning they just want OCR),
        // use Apple's Native Vision framework. It is 100x faster and 100% accurate for text.
        // It avoids 'llava' hallucinations (like seeing "Trash" or "Cats").
        
        // 1. Check Custom Prompt
        let promptToUse = customPrompt ?? SettingsManager.shared.aiPrompt
        
        if promptToUse.isEmpty {
            // MODE: Pure OCR (Text Extraction)
            let recognizedText = recognizeText(from: image)
            // Vision returns "No text detected." if empty, but let's check content length
            if recognizedText == "No text detected." || recognizedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                 completion(.failure(NSError(domain: "OCRShot", code: 404, userInfo: [NSLocalizedDescriptionKey: "No text detected by Apple Vision."])))
            } else {
                 completion(.success(recognizedText))
            }
            return
        }
        
        // 2. MODE: AI Analysis (Custom Prompt present)
        // If user wants to "Describe this image", we proceed to call Ollama (llava) via /api/chat
        
        // Smart Language Detection: Ensure model replies in the prompt's language
        let language = detectLanguage(text: promptToUse)
        var finalPrompt = promptToUse
        if language != "English" && language != "Auto" && language != "Undetermined" {
             finalPrompt += " (Respond in \(language))"
        }
        
        let host = SettingsManager.shared.ollamaHost
        let model = SettingsManager.shared.ollamaModel // e.g. "llava"
        
        guard let url = URL(string: "\(host)/api/chat") else {
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
        
        // Payload for /api/chat
        let messages: [[String: Any]] = [
            [
                "role": "user",
                "content": finalPrompt,
                "images": [base64Image]
            ]
        ]
        
        let body: [String: Any] = [
            "model": model,
            "messages": messages,
            "stream": false,
            "options": [
                "temperature": 0.2 // Slightly creative but focused
            ]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 180 // Increased timeout for long text/images
        
        // Check Proxy
        let proxy = SettingsManager.shared.proxyServer
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
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
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
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let err = json["error"] as? String {
                         completion(.failure(NSError(domain: "OCRShot", code: 500, userInfo: [NSLocalizedDescriptionKey: "Ollama Error: \(err)"])))
                         return
                    }
                    
                    if let message = json["message"] as? [String: Any],
                       let content = message["content"] as? String {
                        completion(.success(content.trimmingCharacters(in: .whitespacesAndNewlines)))
                    } else {
                        completion(.failure(NSError(domain: "OCRShot", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])))
                    }
                } else {
                     completion(.failure(NSError(domain: "OCRShot", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON"])))
                }
            }
        }.resume()
    }
    
    func detectLanguage(text: String) -> String {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        if let lang = recognizer.dominantLanguage {
            return Locale.current.localizedString(forLanguageCode: lang.rawValue) ?? lang.rawValue
        }
        return "Auto"
    }

    // Simplified Request for manual encoding to avoid Any Codable issues
    func translateWithOllama(text: String, from source: String = "Auto", to target: String, completion: @escaping (Result<String, Error>) -> Void) {
        let host = SettingsManager.shared.ollamaHost
        let model = SettingsManager.shared.ollamaTranslationModel
        
        guard let url = URL(string: "\(host)/api/chat") else {
            completion(.failure(NSError(domain: "OCRShot", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid Ollama Host URL"])))
            return
        }
        
        let sourceLang = source == "Auto" ? "the detected language" : source
        
        // Use the customizable prompt from settings
        let systemPrompt = SettingsManager.shared.ollamaTranslationPrompt + " Translate from \(sourceLang) to \(target)."
        
        let messages = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": text]
        ]
        
        // Manual dictionary creation to handle mixed types (Bool, Array, Dict)
        let body: [String: Any] = [
            "model": model,
            "messages": messages,
            "stream": false,
            "options": [
                "temperature": 0.1 // Low temperature for deterministic/strict output
            ]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 180
        
        let session = URLSession.shared
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
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

                // Check for 'message' -> 'content' in response
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let message = json["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    completion(.success(content.trimmingCharacters(in: .whitespacesAndNewlines)))
                } else {
                    // Fallback try decoding struct if standard fails (though we used manual dict parsing above)
                    completion(.failure(NSError(domain: "OCRShot", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response format from Ollama"])))
                }
            }
        }.resume()
    }
    func recognizeText(from image: CGImage) -> String {
        var recognizedText = ""
        
        let request = VNRecognizeTextRequest { request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
            
            let fullText = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }.joined(separator: "\n")
            
            recognizedText = fullText
        }
        
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try? handler.perform([request])
        
        // Basic fallback if Vision fails or returns empty (should rarely happen on standard macOS)
        if recognizedText.isEmpty {
             return "No text detected."
        }
        
        return recognizedText
    }
}
