//
//  TransmutePanel.swift
//  transmute
//
//  Created by Alex Schedrov on 2/17/26.
//

import SwiftUI
import Cocoa
import Combine

final class PanelState: ObservableObject {
    @Published var selectedIndex: Int = 0
    let count: Int
    init(count: Int) { self.count = count }
    func moveUp() { selectedIndex = max(0, selectedIndex - 1) }
    func moveDown() { selectedIndex = min(count - 1, selectedIndex + 1) }
}

class TransmutePanel {
    private static var panel: NSPanel?
    private static var mouseMonitor: Any?
    private static var keyTap: CFMachPort?
    private static var keyTapSource: CFRunLoopSource?
    private static var state: PanelState?
    private static var onActivate: (() -> Void)?

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

        let panelSize = CGSize(width: 560, height: 420)
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .screenSaver
        panel.hasShadow = true
        panel.isOpaque = false
        panel.backgroundColor = .clear

        panel.setFrameOrigin(panelOrigin(size: panelSize))

        let actions = TextAction.builtIn
        let state = PanelState(count: actions.count)
        self.state = state

        let handle: (TextAction) -> Void = { action in
            dismiss()
            Task { await processAndReplace(text: text, action: action) }
        }
        onActivate = {
            guard let idx = self.state?.selectedIndex, actions.indices.contains(idx) else { return }
            handle(actions[idx])
        }

        let view = PanelContentView(selectedText: text, actions: actions, state: state, onAction: handle)

        let hostingView = NSHostingView(rootView: view)
        panel.contentView = hostingView
        panel.orderFrontRegardless()
        self.panel = panel

        installDismissMonitors()
    }

    /// Centered on the active screen, Spotlight-style — slightly above vertical
    /// center so the panel sits in the natural reading zone.
    private static func panelOrigin(size: CGSize) -> NSPoint {
        let screen = NSScreen.main ?? NSScreen.screens.first!
        let visible = screen.visibleFrame
        let x = visible.midX - size.width / 2
        let y = visible.midY - size.height / 2 + visible.height * 0.15
        return NSPoint(x: x, y: y)
    }

    private static func installDismissMonitors() {
        // Outside mouse clicks → dismiss. No need to swallow — let them reach
        // whatever the user clicked on.
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { _ in dismiss() }

        // Keyboard navigation. Must use a CGEvent tap (not an NSEvent monitor)
        // because the panel is non-activating, key events never reach our
        // process, and we need to *swallow* arrow keys so they don't move the
        // cursor in the source app underneath.
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, _ in
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    if let tap = TransmutePanel.keyTap { CGEvent.tapEnable(tap: tap, enable: true) }
                    return Unmanaged.passRetained(event)
                }
                let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
                switch keyCode {
                case 0x35: // Escape
                    DispatchQueue.main.async { TransmutePanel.dismiss() }
                    return nil
                case 0x7E: // Up arrow
                    DispatchQueue.main.async { TransmutePanel.state?.moveUp() }
                    return nil
                case 0x7D: // Down arrow
                    DispatchQueue.main.async { TransmutePanel.state?.moveDown() }
                    return nil
                case 0x24, 0x4C: // Return, keypad Enter
                    DispatchQueue.main.async { TransmutePanel.onActivate?() }
                    return nil
                default:
                    return Unmanaged.passRetained(event)
                }
            },
            userInfo: nil
        ) else { return }

        keyTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        keyTapSource = source
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    static func dismiss() {
        if let m = mouseMonitor { NSEvent.removeMonitor(m); mouseMonitor = nil }
        if let tap = keyTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = keyTapSource {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
            }
            keyTap = nil
            keyTapSource = nil
        }
        state = nil
        onActivate = nil
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
    let actions: [TextAction]
    @ObservedObject var state: PanelState
    let onAction: (TextAction) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Preview of selected text — Spotlight-style "query" row
            HStack(spacing: 14) {
                Image(systemName: "text.quote")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(.secondary)
                Text(selectedText.prefix(120) + (selectedText.count > 120 ? "…" : ""))
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 18)

            Divider().opacity(0.4)

            // Actions list
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(Array(actions.enumerated()), id: \.element.id) { index, action in
                            Button { onAction(action) } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: action.icon)
                                        .font(.system(size: 18, weight: .regular))
                                        .frame(width: 28)
                                        .foregroundStyle(.tint)
                                    Text(action.name)
                                        .font(.system(size: 18, weight: .regular))
                                        .foregroundStyle(.primary)
                                    Spacer()
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 22)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(SpotlightRowButtonStyle(highlighted: index == state.selectedIndex))
                            .id(index)
                            .onHover { hovering in
                                if hovering { state.selectedIndex = index }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                .onChange(of: state.selectedIndex) { _, newValue in
                    withAnimation(.easeOut(duration: 0.12)) {
                        proxy.scrollTo(newValue, anchor: .center)
                    }
                }
            }
        }
        .frame(width: 560, height: 420)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct SpotlightRowButtonStyle: ButtonStyle {
    let highlighted: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(fillColor(pressed: configuration.isPressed))
                    .padding(.horizontal, 10)
            )
    }
    private func fillColor(pressed: Bool) -> Color {
        if pressed { return Color.accentColor.opacity(0.35) }
        if highlighted { return Color.accentColor.opacity(0.22) }
        return .clear
    }
}

#Preview {
    PanelContentView(
        selectedText: "Test text",
        actions: TextAction.builtIn,
        state: PanelState(count: TextAction.builtIn.count)
    ) { _ in }
}
