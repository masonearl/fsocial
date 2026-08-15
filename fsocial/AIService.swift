//
//  AIService.swift
//  fsocial
//
//  Created by Mason Earl on 1/11/26.
//

import Foundation
import SwiftUI
import Combine

// MARK: - AI Provider
enum AIProvider: String, CaseIterable, Identifiable, Codable {
    case claude = "Claude (Anthropic)"
    case openai = "OpenAI (GPT)"
    case grok = "Grok (xAI)"
    case gemini = "Gemini (Google)"
    case ollama = "Ollama (Local)"
    
    var id: String { rawValue }
    
    var keyPlaceholder: String {
        switch self {
        case .claude: return "sk-ant-..."
        case .openai: return "sk-..."
        case .grok: return "xai-..."
        case .gemini: return "AI..."
        case .ollama: return "http://localhost:11434"
        }
    }
    
    var keyLabel: String {
        switch self {
        case .ollama: return "Ollama URL"
        default: return "API Key"
        }
    }
    
    var setupURL: String {
        switch self {
        case .claude: return "https://console.anthropic.com"
        case .openai: return "https://platform.openai.com/api-keys"
        case .grok: return "https://console.x.ai"
        case .gemini: return "https://aistudio.google.com/apikey"
        case .ollama: return "https://ollama.ai"
        }
    }
    
    var iconName: String {
        switch self {
        case .claude: return "brain.head.profile"
        case .openai: return "sparkles"
        case .grok: return "xmark.circle"
        case .gemini: return "diamond"
        case .ollama: return "desktopcomputer"
        }
    }
}

class AIService: ObservableObject {
    private let providerKey = "com.fsocial.ai.provider"
    private let apiKeyPrefix = "com.fsocial.ai.key."
    
    @Published var isLoading = false
    @Published var suggestedReplies: [String] = []
    @Published var lastError: String?
    @Published var selectedProvider: AIProvider = .claude
    @Published var hasAPIKey: Bool = false
    
    init() {
        loadProvider()
        hasAPIKey = getAPIKey() != nil
    }
    
    // MARK: - Provider Management
    
    private func loadProvider() {
        if let savedProvider = UserDefaults.standard.string(forKey: providerKey),
           let provider = AIProvider(rawValue: savedProvider) {
            selectedProvider = provider
        }
    }
    
    func setProvider(_ provider: AIProvider) {
        selectedProvider = provider
        UserDefaults.standard.set(provider.rawValue, forKey: providerKey)
        hasAPIKey = getAPIKey() != nil
        suggestedReplies = [] // Clear old suggestions
    }
    
    // MARK: - API Key Management (Keychain)
    
    private func account(for provider: AIProvider) -> String {
        apiKeyPrefix + provider.rawValue
    }
    
    @discardableResult
    func saveAPIKey(_ key: String) -> Bool {
        do {
            try KeychainHelper.save(account: account(for: selectedProvider), secret: key)
            // Remove any legacy plaintext copy from UserDefaults
            UserDefaults.standard.removeObject(forKey: account(for: selectedProvider))
            hasAPIKey = true
            lastError = nil
            return true
        } catch {
            lastError = "Could not save API key: \(error.localizedDescription)"
            return false
        }
    }
    
    func getAPIKey() -> String? {
        do {
            if let key = try KeychainHelper.load(account: account(for: selectedProvider)) {
                return key
            }
            // One-time migration from older plaintext UserDefaults storage
            let legacyKey = account(for: selectedProvider)
            if let legacy = UserDefaults.standard.string(forKey: legacyKey), !legacy.isEmpty {
                try KeychainHelper.save(account: legacyKey, secret: legacy)
                UserDefaults.standard.removeObject(forKey: legacyKey)
                return legacy
            }
            return nil
        } catch {
            lastError = "Could not read API key: \(error.localizedDescription)"
            return nil
        }
    }
    
    func clearAPIKey() {
        do {
            try KeychainHelper.delete(account: account(for: selectedProvider))
            UserDefaults.standard.removeObject(forKey: account(for: selectedProvider))
            hasAPIKey = false
            lastError = nil
        } catch {
            lastError = "Could not remove API key: \(error.localizedDescription)"
        }
    }
    
    func hasKey(for provider: AIProvider) -> Bool {
        if let key = try? KeychainHelper.load(account: account(for: provider)), !key.isEmpty {
            return true
        }
        return UserDefaults.standard.string(forKey: account(for: provider)) != nil
    }
    
    // MARK: - Generate Smart Replies
    
    func generateReplies(for content: String, platform: Platform) {
        guard let apiKey = getAPIKey(), !apiKey.isEmpty else {
            lastError = "No API key configured"
            return
        }
        
        guard !content.isEmpty else {
            suggestedReplies = []
            return
        }
        
        isLoading = true
        lastError = nil
        
        let prompt = buildPrompt(content: content, platform: platform)
        
        Task {
            do {
                let replies: [String]
                switch selectedProvider {
                case .claude:
                    replies = try await callClaude(prompt: prompt, apiKey: apiKey)
                case .openai:
                    replies = try await callOpenAI(prompt: prompt, apiKey: apiKey)
                case .grok:
                    replies = try await callGrok(prompt: prompt, apiKey: apiKey)
                case .gemini:
                    replies = try await callGemini(prompt: prompt, apiKey: apiKey)
                case .ollama:
                    replies = try await callOllama(prompt: prompt, baseURL: apiKey)
                }
                
                DispatchQueue.main.async {
                    self.suggestedReplies = replies
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.lastError = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    private func buildPrompt(content: String, platform: Platform) -> String {
        return """
        You're replying to this \(platform.rawValue) post as a real person. Be authentic and conversational.
        
        POST: "\(content.prefix(400))"
        
        Write 3 different reply options (each under 80 chars):
        - One genuine/supportive
        - One clever/witty  
        - One adds value/insight
        
        Rules:
        - Sound human, not corporate
        - NO emojis ever
        - No hashtags
        - Lowercase okay, be casual
        - Match the vibe of the original post
        
        Just the 3 replies, one per line. No labels or numbers.
        """
    }
    
    // MARK: - Claude API
    
    private func callClaude(prompt: String, apiKey: String) async throws -> [String] {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": "claude-sonnet-4-20250514",
            "max_tokens": 150,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorObj = errorJson["error"] as? [String: Any],
               let message = errorObj["message"] as? String {
                throw AIError.apiError(message)
            }
            throw AIError.httpError(httpResponse.statusCode)
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstContent = content.first,
              let text = firstContent["text"] as? String else {
            throw AIError.parseError
        }
        
        return parseReplies(text)
    }
    
    // MARK: - OpenAI API
    
    private func callOpenAI(prompt: String, apiKey: String) async throws -> [String] {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "max_tokens": 150,
            "temperature": 0.8
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorJson["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw AIError.apiError(message)
            }
            throw AIError.httpError(httpResponse.statusCode)
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIError.parseError
        }
        
        return parseReplies(content)
    }
    
    // MARK: - Grok API (xAI)
    
    private func callGrok(prompt: String, apiKey: String) async throws -> [String] {
        let url = URL(string: "https://api.x.ai/v1/chat/completions")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": "grok-beta",
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "max_tokens": 150,
            "temperature": 0.8
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorJson["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw AIError.apiError(message)
            }
            throw AIError.httpError(httpResponse.statusCode)
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIError.parseError
        }
        
        return parseReplies(content)
    }
    
    // MARK: - Gemini API (Google)
    
    private func callGemini(prompt: String, apiKey: String) async throws -> [String] {
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=\(apiKey)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "contents": [
                ["parts": [["text": prompt]]]
            ],
            "generationConfig": [
                "maxOutputTokens": 300,
                "temperature": 0.8
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorJson["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw AIError.apiError(message)
            }
            throw AIError.httpError(httpResponse.statusCode)
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String else {
            throw AIError.parseError
        }
        
        return parseReplies(text)
    }
    
    // MARK: - Ollama (Local)
    
    private func callOllama(prompt: String, baseURL: String) async throws -> [String] {
        let urlString = baseURL.hasSuffix("/") ? "\(baseURL)api/generate" : "\(baseURL)/api/generate"
        guard let url = URL(string: urlString) else {
            throw AIError.apiError("Invalid Ollama URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": "llama3.2",
            "prompt": prompt,
            "stream": false
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            throw AIError.httpError(httpResponse.statusCode)
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let text = json["response"] as? String else {
            throw AIError.parseError
        }
        
        return parseReplies(text)
    }
    
    // MARK: - Parse Replies
    
    private func parseReplies(_ text: String) -> [String] {
        return text
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .map { line -> String in
                // Remove common prefixes like "1.", "- ", "• ", etc.
                var cleaned = line
                if let range = cleaned.range(of: #"^[\d]+[.\)]\s*"#, options: .regularExpression) {
                    cleaned.removeSubrange(range)
                }
                if cleaned.hasPrefix("- ") { cleaned.removeFirst(2) }
                if cleaned.hasPrefix("• ") { cleaned.removeFirst(2) }
                if cleaned.hasPrefix("* ") { cleaned.removeFirst(2) }
                // Remove any emojis
                cleaned = removeEmojis(from: cleaned)
                return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty && $0.count > 5 }
            .prefix(3)
            .map { String($0) }
    }
    
    private func removeEmojis(from text: String) -> String {
        return text.unicodeScalars
            .filter { scalar in
                // Keep basic ASCII, extended Latin, punctuation
                let value = scalar.value
                // Basic Latin + Latin Extended + common punctuation
                if value <= 0x024F { return true }
                // General punctuation
                if value >= 0x2000 && value <= 0x206F { return true }
                // Skip emojis and symbols
                if value >= 0x1F300 { return false }
                if value >= 0x2600 && value <= 0x27BF { return false }
                return true
            }
            .map { String($0) }
            .joined()
    }
}

// MARK: - AI Errors
enum AIError: LocalizedError {
    case invalidResponse
    case httpError(Int)
    case apiError(String)
    case parseError
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .apiError(let message):
            return message
        case .parseError:
            return "Failed to parse response"
        }
    }
}
