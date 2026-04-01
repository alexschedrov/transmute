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

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .anthropic: "Anthropic"
        case .openai: "OpenAI"
        case .gemini: "Google Gemini"
        }
    }

    var apiKeyStorageKey: String {
        switch self {
        case .anthropic: "anthropicAPIKey"
        case .openai: "openaiAPIKey"
        case .gemini: "geminiAPIKey"
        }
    }

    var placeholder: String {
        switch self {
        case .anthropic: "sk-ant-…"
        case .openai: "sk-…"
        case .gemini: "AI…"
        }
    }

    var helpText: String {
        switch self {
        case .anthropic: "Get your key at console.anthropic.com"
        case .openai: "Get your key at platform.openai.com"
        case .gemini: "Get your key at aistudio.google.com"
        }
    }

    var defaultModel: String {
        switch self {
        case .anthropic: "claude-sonnet-4-20250514"
        case .openai: "gpt-4o"
        case .gemini: "gemini-2.0-flash"
        }
    }
}
