//
//  LLMService.swift
//  transmute
//
//  Created by Alex Schedrov on 2/17/26.
//

import Foundation

class LLMService {
    static let shared = LLMService()

    private var apiKey: String {
        UserDefaults.standard.string(forKey: "anthropicAPIKey") ?? ""
    }

    func process(text: String, action: TextAction) async -> String {
        guard !apiKey.isEmpty else {
            return "[Set your API key in Transmute settings]"
        }

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": "claude-sonnet-4-20250514",
            "max_tokens": 4096,
            "messages": [
                ["role": "user", "content": "\(action.prompt)\n\n\(text)"]
            ]
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return "[API error — check your key and try again]"
            }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let content = json["content"] as? [[String: Any]],
               let text = content.first?["text"] as? String {
                return text
            }

            return "[Unexpected response format]"
        } catch {
            return "[Network error: \(error.localizedDescription)]"
        }
    }
}

