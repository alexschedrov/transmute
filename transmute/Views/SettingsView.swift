//
//  SettingsView.swift
//  transmute
//
//  Created by Alex Schedrov on 2/17/26.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("anthropicAPIKey") private var apiKey: String = ""

    var body: some View {
        TabView {
            Form {
                Section("Anthropic API Key") {
                    SecureField("sk-ant-…", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                    Text("Get your key at console.anthropic.com")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section("Shortcut") {
                    HStack {
                        Text("Trigger")
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
        .frame(width: 420, height: 220)
    }
}
