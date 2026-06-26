//
//  SettingsView.swift
//  transmute
//
//  Created by Alex Schedrov on 2/17/26.
//

import SwiftUI
import ServiceManagement

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem { Label("General", systemImage: "gear") }
            LLMSettingsTab()
                .tabItem { Label("LLM", systemImage: "brain") }
            CommandsSettingsTab()
                .tabItem { Label("Commands", systemImage: "list.bullet") }
        }
        .frame(width: 500, height: 440)
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
        NSApp.setActivationPolicy(.prohibited)
        NSApp.setActivationPolicy(.accessory)
    }
}

// MARK: - General Tab

private struct GeneralSettingsTab: View {
    @AppStorage("hotkeyKeyCode") private var hotkeyKeyCode: Int = Int(Shortcut.default.keyCode)
    @AppStorage("hotkeyModifiers") private var hotkeyModifiersRaw: Int = Int(Shortcut.default.modifiers.rawValue)
    @AppStorage("hotkeyKeyLabel") private var hotkeyKeyLabel: String = Shortcut.default.keyLabel
    @State private var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled
    @State private var accessibilityGranted: Bool = AXIsProcessTrusted()

    private var currentShortcut: Shortcut {
        Shortcut(
            keyCode: UInt16(hotkeyKeyCode),
            modifiers: CGEventFlags(rawValue: UInt64(hotkeyModifiersRaw)),
            keyLabel: hotkeyKeyLabel
        )
    }

    private func setShortcut(_ shortcut: Shortcut) {
        hotkeyKeyCode = Int(shortcut.keyCode)
        hotkeyModifiersRaw = Int(shortcut.modifiers.rawValue)
        hotkeyKeyLabel = shortcut.keyLabel
    }

    var body: some View {
        Form {
            Section {
                LabeledContent("Keyboard Shortcut") {
                    HStack(spacing: 8) {
                        ShortcutRecorderView(shortcut: currentShortcut, onChange: setShortcut)
                        if currentShortcut != .default {
                            Button("Reset") { setShortcut(.default) }
                                .controlSize(.small)
                        }
                    }
                }
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        do {
                            if enabled {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
            }

            Section("Permissions") {
                HStack(spacing: 12) {
                    if accessibilityGranted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .imageScale(.large)
                        Text("Accessibility access granted")
                    } else {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                            .imageScale(.large)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Accessibility access required")
                                .fontWeight(.medium)
                            Text("Needed to read and replace selected text.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Open System Settings") {
                            NSWorkspace.shared.open(
                                URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                            )
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .formStyle(.grouped)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            accessibilityGranted = AXIsProcessTrusted()
        }
        .onAppear {
            accessibilityGranted = AXIsProcessTrusted()
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

// MARK: - LLM Tab

private struct LLMSettingsTab: View {
    @AppStorage("llmProvider") private var selectedProvider: String = LLMProvider.openai.rawValue
    @AppStorage("model_anthropic") private var modelAnthropic: String = ""
    @AppStorage("model_openai") private var modelOpenai: String = ""
    @AppStorage("model_gemini") private var modelGemini: String = ""
    @AppStorage("model_local") private var modelLocal: String = ""
    @AppStorage("localServerURL") private var localServerURL: String = ""
    @State private var apiKeys: [LLMProvider: String] = [:]
    @State private var pickerSelection: String = "__default__"

    private var provider: LLMProvider {
        LLMProvider(rawValue: selectedProvider) ?? .anthropic
    }

    private var modelBinding: Binding<String> {
        switch provider {
        case .anthropic: return $modelAnthropic
        case .openai: return $modelOpenai
        case .gemini: return $modelGemini
        case .local: return $modelLocal
        }
    }

    private var apiKeyBinding: Binding<String> {
        Binding(
            get: { apiKeys[provider] ?? "" },
            set: { newValue in
                apiKeys[provider] = newValue
                KeychainService.save(newValue, account: provider.apiKeyStorageKey)
            }
        )
    }

    private func syncPicker() {
        let stored = modelBinding.wrappedValue
        if stored.isEmpty {
            pickerSelection = "__default__"
        } else if provider.knownModels.contains(stored) {
            pickerSelection = stored
        } else {
            pickerSelection = "__custom__"
        }
    }

    var body: some View {
        Form {
            Section {
                Picker("Provider", selection: $selectedProvider) {
                    ForEach(LLMProvider.allCases) { p in
                        Text(p.displayName).tag(p.rawValue)
                    }
                }
                .onChange(of: selectedProvider) { _, _ in syncPicker() }

                if provider == .local {
                    LabeledContent("URL") {
                        TextField(
                            text: $localServerURL,
                            prompt: Text("http://localhost:11434").foregroundStyle(.secondary)
                        ) { EmptyView() }
                            .textFieldStyle(.roundedBorder)
                    }
                    LabeledContent("Model") {
                        TextField(
                            text: modelBinding,
                            prompt: Text(provider.defaultModel).foregroundStyle(.secondary)
                        ) { EmptyView() }
                            .textFieldStyle(.roundedBorder)
                    }
                } else {
                    Picker("Model", selection: $pickerSelection) {
                        Text("Default (\(provider.defaultModel))").tag("__default__")
                        Divider()
                        ForEach(provider.knownModels, id: \.self) { m in
                            Text(m).tag(m)
                        }
                        Divider()
                        Text("Other…").tag("__custom__")
                    }
                    .onChange(of: pickerSelection) { _, tag in
                        switch tag {
                        case "__default__": modelBinding.wrappedValue = ""
                        case "__custom__": break
                        default: modelBinding.wrappedValue = tag
                        }
                    }
                    if pickerSelection == "__custom__" {
                        LabeledContent("Custom Model") {
                            TextField(
                                text: modelBinding,
                                prompt: Text(provider.defaultModel).foregroundStyle(.secondary)
                            ) { EmptyView() }
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                }
            } footer: {
                Text("Leave model blank to use the provider's default.")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if provider.requiresAPIKey {
                Section {
                    SecureField(provider.placeholder, text: apiKeyBinding)
                } header: {
                    Text("API Key")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Stored securely in your macOS Keychain.", systemImage: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        if let url = provider.keyURL {
                            Link("Get your API key →", destination: url)
                                .font(.caption)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                Section {
                    Label("No API key required.", systemImage: "checkmark.circle")
                        .foregroundStyle(.secondary)
                } header: {
                    Text("API Key")
                } footer: {
                    Text("Works with any OpenAI-compatible local server - Ollama, LM Studio, Jan, or similar. Make sure the server is running and the model is loaded.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            for p in LLMProvider.allCases where p.requiresAPIKey {
                apiKeys[p] = KeychainService.read(account: p.apiKeyStorageKey) ?? ""
            }
            syncPicker()
        }
    }
}

// MARK: - Commands Tab

private struct CommandsSettingsTab: View {
    @State private var commands: [CustomCommand] = UserDefaults.standard.customCommands
    @State private var selection: UUID?
    @State private var editingCommand: CustomCommand?

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $selection) {
                if !commands.isEmpty {
                    Section("Custom") {
                        ForEach(commands) { command in
                            CommandRow(command: command)
                                .tag(command.id)
                                .onTapGesture(count: 2) { beginEditing(command) }
                        }
                    }
                }

                Section("Built-in") {
                    ForEach(TextAction.builtIn.filter { !$0.isCustom }) { action in
                        HStack(spacing: 10) {
                            Image(systemName: action.icon)
                                .frame(width: 20)
                                .foregroundStyle(.tertiary)
                            Text(action.name)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .listStyle(.inset)

            Divider()

            HStack(spacing: 0) {
                Button { addCommand() } label: {
                    Image(systemName: "plus")
                        .frame(width: 28, height: 24)
                }
                .buttonStyle(.borderless)
                .padding(.horizontal, 4)

                Divider().frame(height: 16)

                Button { removeSelected() } label: {
                    Image(systemName: "minus")
                        .frame(width: 28, height: 24)
                }
                .buttonStyle(.borderless)
                .padding(.horizontal, 4)
                .disabled(selection == nil || !commands.contains(where: { $0.id == selection }))

                Spacer()

                if let sel = selection, let cmd = commands.first(where: { $0.id == sel }) {
                    Button("Edit") { beginEditing(cmd) }
                        .buttonStyle(.borderless)
                        .padding(.trailing, 8)
                }
            }
            .padding(.vertical, 4)
        }
        .sheet(item: $editingCommand) { cmd in
            CommandEditorView(command: cmd) { saved in
                if let idx = commands.firstIndex(where: { $0.id == saved.id }) {
                    commands[idx] = saved
                } else {
                    commands.append(saved)
                }
                persist()
                editingCommand = nil
            } onCancel: {
                editingCommand = nil
            }
        }
    }

    private func addCommand() {
        editingCommand = CustomCommand()
    }

    private func beginEditing(_ command: CustomCommand) {
        guard commands.contains(where: { $0.id == command.id }) else { return }
        editingCommand = command
    }

    private func removeSelected() {
        guard let id = selection, let idx = commands.firstIndex(where: { $0.id == id }) else { return }
        commands.remove(at: idx)
        selection = nil
        persist()
    }

    private func persist() {
        UserDefaults.standard.customCommands = commands
    }
}

private struct CommandRow: View {
    let command: CustomCommand

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: command.icon.isEmpty ? "questionmark" : command.icon)
                .frame(width: 20)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(command.name.isEmpty ? "Untitled" : command.name)
                Text(command.prompt)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
    }
}

// MARK: - Command Editor Sheet

private struct CommandEditorView: View {
    @State var command: CustomCommand
    let onSave: (CustomCommand) -> Void
    let onCancel: () -> Void

    private var isIconValid: Bool {
        command.icon.isEmpty ||
        NSImage(systemSymbolName: command.icon, accessibilityDescription: nil) != nil
    }

    var isValid: Bool {
        !command.name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !command.prompt.trimmingCharacters(in: .whitespaces).isEmpty &&
        isIconValid
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    LabeledContent("Name") {
                        TextField(
                            text: $command.name,
                            prompt: Text("My Command").foregroundStyle(.secondary)
                        ) { EmptyView() }
                    }
                }

                Section {
                    LabeledContent("Icon") {
                        HStack(spacing: 8) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(.quaternary)
                                    .frame(width: 28, height: 28)
                                if command.icon.isEmpty {
                                    Image(systemName: "questionmark")
                                        .foregroundStyle(.tertiary)
                                } else if isIconValid {
                                    Image(systemName: command.icon)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(.red)
                                }
                            }
                            .font(.body)

                            TextField(
                                text: $command.icon,
                                prompt: Text("wand.and.stars").foregroundStyle(.secondary)
                            ) { EmptyView() }
                        }
                    }
                } footer: {
                    Link("Browse all icons in SF Symbols →",
                         destination: URL(string: "https://developer.apple.com/sf-symbols/")!)
                        .font(.caption)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Section("Prompt") {
                    TextEditor(text: $command.prompt)
                        .font(.body)
                        .frame(minHeight: 88)
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Button("Cancel", role: .cancel) { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") { onSave(command) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isValid)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(width: 420, height: 380)
    }
}

#Preview {
    SettingsView()
}
