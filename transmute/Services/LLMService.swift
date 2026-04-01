//
//  LLMService.swift
//  transmute
//
//  Created by Alex Schedrov on 2/17/26.
//

import Foundation

class LLMService {
    static let shared = LLMService()

    private var provider: LLMProvider {
        LLMProvider(rawValue: UserDefaults.standard.string(forKey: "llmProvider") ?? "anthropic") ?? .anthropic
    }

    private var apiKey: String {
        UserDefaults.standard.string(forKey: provider.apiKeyStorageKey) ?? ""
    }

    func process(text: String, prompt: String) async -> String {
        guard !apiKey.isEmpty else {
            return "[Set your \(provider.displayName) API key in Transmute settings]"
        }

        let request: URLRequest
        switch provider {
        case .anthropic: request = buildAnthropicRequest(text: text, prompt: prompt)
        case .openai: request = buildOpenAIRequest(text: text, prompt: prompt)
        case .gemini: request = buildGeminiRequest(text: text, prompt: prompt)
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return "[API error — check your key and try again]"
            }

            return parseResponse(data: data)
        } catch {
            return "[Network error: \(error.localizedDescription)]"
        }
    }

    // MARK: - Request Builders

    private func buildAnthropicRequest(text: String, prompt: String) -> URLRequest {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": provider.defaultModel,
            "max_tokens": 4096,
            "messages": [["role": "user", "content": "\(prompt)\n\n\(text)"]]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return request
    }

    private func buildOpenAIRequest(text: String, prompt: String) -> URLRequest {
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "authorization")

        let body: [String: Any] = [
            "model": provider.defaultModel,
            "max_tokens": 4096,
            "messages": [["role": "user", "content": "\(prompt)\n\n\(text)"]]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return request
    }

    private func buildGeminiRequest(text: String, prompt: String) -> URLRequest {
        let url = "https://generativelanguage.googleapis.com/v1beta/models/\(provider.defaultModel):generateContent?key=\(apiKey)"
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let body: [String: Any] = [
            "contents": [["parts": [["text": "\(prompt)\n\n\(text)"]]]]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return request
    }

    // MARK: - Response Parsing

    private func parseResponse(data: Data) -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return "[Unexpected response format]"
        }

        switch provider {
        case .anthropic:
            if let content = json["content"] as? [[String: Any]],
               let text = content.first?["text"] as? String {
                return text
            }
        case .openai:
            if let choices = json["choices"] as? [[String: Any]],
               let message = choices.first?["message"] as? [String: Any],
               let text = message["content"] as? String {
                return text
            }
        case .gemini:
            if let candidates = json["candidates"] as? [[String: Any]],
               let content = candidates.first?["content"] as? [String: Any],
               let parts = content["parts"] as? [[String: Any]],
               let text = parts.first?["text"] as? String {
                return text
            }
        }

        return "[Unexpected response format]"
    }
}
