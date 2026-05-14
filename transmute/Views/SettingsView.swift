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
    @AppStorage("userVoice") private var userVoice: String = ""

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
            generalForm
                .padding()
                .tabItem { Label("General", systemImage: "gear") }
        }
        .frame(width: 420, height: 460)
        .onAppear(perform: showInDock)
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { notification in
            guard let window = notification.object as? NSWindow, isSettingsWindow(window) else { return }
            window.level = .floating
            window.orderFrontRegardless()
            window.level = .normal
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { _ in
            DispatchQueue.main.async { hideFromDockIfNoRegularWindows() }
        }
    }

    private var generalForm: some View {
        Form {
            providerSection
            apiKeySection
            voiceSection
            shortcutSection
        }
    }

    private var providerSection: some View {
        Section("LLM Provider") {
            Picker("Provider", selection: $selectedProvider) {
                ForEach(LLMProvider.allCases) { p in
                    Text(p.displayName).tag(p.rawValue)
                }
            }
        }
    }

    private var apiKeySection: some View {
        Section("API Key") {
            SecureField(provider.placeholder, text: apiKeyBinding)
                .textFieldStyle(.roundedBorder)
            Text(provider.helpText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var voiceSection: some View {
        Section("Your writing style") {
            TextEditor(text: $userVoice)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 96)
                .border(.quaternary)
            Text("Optional. A few sentences describing how you write — audience, language, register, quirks. Used as context for every transformation.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var shortcutSection: some View {
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

    private func isSettingsWindow(_ window: NSWindow) -> Bool {
        window.title.contains("Settings") || window.title.contains("Transmute")
    }

    private func showInDock() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func hideFromDockIfNoRegularWindows() {
        let hasRegular = NSApp.windows.contains { $0.isVisible && $0.styleMask.contains(.titled) }
        guard !hasRegular else { return }
        // .accessory alone doesn't refresh the Dock while the app is frontmost.
        // The .prohibited→.accessory bounce forces the Dock to release the icon
        // without yielding focus to another app. The MenuBarExtra (NSStatusItem)
        // survives the transition.
        NSApp.setActivationPolicy(.prohibited)
        NSApp.setActivationPolicy(.accessory)
    }
}

#Preview {
    SettingsView()
}
