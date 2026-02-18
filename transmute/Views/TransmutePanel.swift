//
//  TransmutePanel.swift
//  transmute
//
//  Created by Alex Schedrov on 2/17/26.
//

import SwiftUI
import Cocoa

class TransmutePanel {
    private static var panel: NSPanel?

    static func show() {
        print(">>> show() called")
        Task {
            print(">>> Task started, getting text...")
            guard let text = await AccessibilityService.getSelectedText() else {
                print(">>> No text selected")
                return
            }
            print(">>> Got text: \(text.prefix(30))")
            await MainActor.run {
                print(">>> Showing panel")
                showPanel(with: text)
            }
        }
    }

    private static func showPanel(with text: String) {
        dismiss()

        let mouseLocation = NSEvent.mouseLocation

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 300),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .screenSaver
        panel.hasShadow = true
        panel.backgroundColor = .windowBackgroundColor

        // Position above cursor
        panel.setFrameOrigin(NSPoint(
            x: mouseLocation.x - 140,
            y: mouseLocation.y + 10
        ))

        let view = PanelContentView(selectedText: text) { action in
            dismiss()
            Task { await processAndReplace(text: text, action: action) }
        }

        let hostingView = NSHostingView(rootView: view)
        panel.contentView = hostingView
        panel.orderFrontRegardless()
        self.panel = panel
    }

    static func dismiss() {
        panel?.close()
        panel = nil
    }

    private static func processAndReplace(text: String, action: TextAction) async {
        let result = await action.apply(to: text)
        await MainActor.run {
            AccessibilityService.replaceSelectedText(with: result)
        }
    }
}

// MARK: - Panel SwiftUI Content

struct PanelContentView: View {
    let selectedText: String
    let onAction: (TextAction) -> Void
    @State private var searchText = ""

    private var filteredActions: [TextAction] {
        if searchText.isEmpty { return TextAction.builtIn }
        return TextAction.builtIn.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Preview of selected text
            HStack {
                Image(systemName: "text.quote")
                    .foregroundColor(.secondary)
                Text(selectedText.prefix(60) + (selectedText.count > 60 ? "…" : ""))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Search/filter
            TextField("Search actions…", text: $searchText)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            Divider()

            // Actions list
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(filteredActions) { action in
                        Button { onAction(action) } label: {
                            HStack(spacing: 10) {
                                Image(systemName: action.icon)
                                    .frame(width: 20)
                                    .foregroundColor(.accentColor)
                                Text(action.name)
                                Spacer()
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .frame(width: 260, height: 280)
    }
}

