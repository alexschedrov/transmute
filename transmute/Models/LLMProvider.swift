//
//  LLMProvider.swift
//  transmute
//
//  Created by Alex Schedrov on 3/31/26.
//

import Foundation

enum LLMProvider: String, CaseIterable, Identifiable {
    case anthropic
    case openai
    case gemini
    case local

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .anthropic: "Anthropic"
        case .openai: "OpenAI"
        case .gemini: "Google Gemini"
        case .local: "Local Server"
        }
    }

    var apiKeyStorageKey: String {
        switch self {
        case .anthropic: "anthropicAPIKey"
        case .openai: "openaiAPIKey"
        case .gemini: "geminiAPIKey"
        case .local: ""
        }
    }

    var requiresAPIKey: Bool {
        self != .local
    }

    var placeholder: String {
        switch self {
        case .anthropic: "sk-ant-…"
        case .openai: "sk-…"
        case .gemini: "AI…"
        case .local: ""
        }
    }

    var keyURL: URL? {
        switch self {
        case .anthropic: URL(string: "https://console.anthropic.com/settings/keys")
        case .openai: URL(string: "https://platform.openai.com/api-keys")
        case .gemini: URL(string: "https://aistudio.google.com/app/apikey")
        case .local: nil
        }
    }

    var defaultModel: String {
        switch self {
        case .anthropic: "claude-sonnet-4-6"
        case .openai: "gpt-4o"
        case .gemini: "gemini-2.5-flash"
        case .local: "llama3.2"
        }
    }

    var knownModels: [String] {
        switch self {
        case .anthropic: ["claude-fable-5", "claude-opus-4-8", "claude-sonnet-4-6", "claude-haiku-4-5-20251001"]
        case .openai: ["gpt-5.5", "gpt-5.4", "gpt-5.4-mini", "gpt-4o", "gpt-4o-mini"]
        case .gemini: ["gemini-3.5-flash", "gemini-2.5-pro", "gemini-2.5-flash", "gemini-2.5-flash-lite"]
        case .local: []
        }
    }
}
