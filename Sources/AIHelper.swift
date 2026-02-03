// This program was developed by Levko Kravchuk with the help of Vibe Coding
import Cocoa
import Vision

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
                // Check for API errors (Ollama returns JSON error sometimes)
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
    
    func translateWithOllama(text: String, to language: String, completion: @escaping (Result<String, Error>) -> Void) {
        let host = SettingsManager.shared.ollamaHost
        let model = SettingsManager.shared.ollamaModel
        
        guard let url = URL(string: "\(host)/api/generate") else {
            completion(.failure(NSError(domain: "OCRShot", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid Ollama Host URL"])))
            return
        }
        
        let prompt = "Translate the following text to \(language). Output ONLY the translated text, do not add any explanations or notes. \n\nText: \(text)"
        
        let body = OllamaRequest(
            model: model,
            prompt: prompt,
            images: [],
            stream: false
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60 // Translation might take a moment
        
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
                completion(.success(decoded.response.trimmingCharacters(in: .whitespacesAndNewlines)))
            } catch {
                completion(.failure(error))
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
