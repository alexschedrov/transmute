//
//  SettingsView.swift
//  transmute
//
//  Created by Alex Schedrov on 2/17/26.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("llmProvider") private var selectedProvider: String = LLMProvider.openai.rawValue
    @AppStorage("anthropicAPIKey") private var anthropicKey: String = ""
    @AppStorage("openaiAPIKey") private var openaiKey: String = ""
    @AppStorage("geminiAPIKey") private var geminiKey: String = ""

    private var provider: LLMProvider {
        LLMProvider(rawValue: selectedProvider) ?? .anthropic
    }

    private var apiKeyBinding: Binding<String> {
        switch provider {
        case .anthropic: $anthropicKey
        case .openai: $openaiKey
        case .gemini: $geminiKey
        }
    }

    var body: some View {
        TabView {
            Form {
                Section("LLM Provider") {
                    Picker("Provider", selection: $selectedProvider) {
                        ForEach(LLMProvider.allCases) { p in
                            Text(p.displayName).tag(p.rawValue)
                        }
                    }
                }

                Section("API Key") {
                    SecureField(provider.placeholder, text: apiKeyBinding)
                        .textFieldStyle(.roundedBorder)
                    Text(provider.helpText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section("Shortcut") {
                    HStack {
                        Text("Keyboard Shortcut")
                        Spacer()
                        Text("⌥⇧T")
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.quaternary)
                            .cornerRadius(6)
                    }
                }
            }
            .padding()
            .tabItem { Label("General", systemImage: "gear") }
        }
        .frame(width: 420, height: 280)
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { notification in
            if let window = notification.object as? NSWindow, window.title.contains("Settings") || window.title.contains("Transmute") {
                window.level = .floating
                window.orderFrontRegardless()
                window.level = .normal
            }
        }
    }
}

#Preview {
    SettingsView()
}
