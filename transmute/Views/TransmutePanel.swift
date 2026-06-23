//
//  TransmutePanel.swift
//  transmute
//
//  Created by Alex Schedrov on 2/17/26.
//

import SwiftUI
import Cocoa
import Combine

enum PanelMode { case actions, customInput, processing }

/// Brand gradient applied to every icon inside the panel.
/// Top stop: #A933FF (bright violet). Bottom stop: #B944D1 (bright magenta-purple).
private let panelIconGradient = LinearGradient(
    colors: [
        Color(red: 0xA9 / 255.0, green: 0x33 / 255.0, blue: 0xFF / 255.0),
        Color(red: 0xB9 / 255.0, green: 0x44 / 255.0, blue: 0xD1 / 255.0),
    ],
    startPoint: .top,
    endPoint: .bottom
)

final class PanelState: ObservableObject {
    @Published var selectedIndex: Int = 0
    @Published var mode: PanelMode = .actions
    @Published var processingLabel: String = ""
    let count: Int
    init(count: Int) { self.count = count }
    func moveUp() { selectedIndex = max(0, selectedIndex - 1) }
    func moveDown() { selectedIndex = min(count - 1, selectedIndex + 1) }
}

/// NSPanel subclass that can become key without activating the app.
/// This is required for the custom-input TextField to receive keystrokes
/// while the source app stays visually active underneath.
final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

class TransmutePanel {
    private static var panel: NSPanel?
    private static var mouseMonitor: Any?
    private static var keyTap: CFMachPort?
    private static var keyTapSource: CFRunLoopSource?
    private static var state: PanelState?
    private static var onActivate: (() -> Void)?
    private static var processingTask: Task<Void, Never>?

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
        let panel = KeyablePanel(
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
            if action.isCustom {
                state.mode = .customInput
                return
            }
            startProcessing(label: action.progressLabel ?? action.name, text: text, action: action)
        }
        onActivate = {
            guard let idx = self.state?.selectedIndex, actions.indices.contains(idx) else { return }
            handle(actions[idx])
        }

        let onCustomSubmit: (String) -> Void = { userPrompt in
            let trimmed = userPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            let wrapped = "Apply the following instruction to the input: \(trimmed)"
            let custom = TextAction(name: "Custom", icon: "wand.and.stars", prompt: wrapped)
            startProcessing(label: "Transmuting", text: text, action: custom)
        }

        let view = PanelContentView(
            selectedText: text,
            actions: actions,
            state: state,
            onAction: handle,
            onCustomSubmit: onCustomSubmit
        )

        let hostingView = NSHostingView(rootView: view)
        panel.contentView = hostingView
        panel.orderFrontRegardless()
        panel.makeKey()
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

                // Escape always dismisses, in any mode.
                if keyCode == 0x35 {
                    DispatchQueue.main.async { TransmutePanel.dismiss() }
                    return nil
                }

                // In custom-input mode the text field owns the keyboard —
                // don't swallow anything else (arrows move caret, Return submits
                // via SwiftUI's onSubmit, typing fills the field). While
                // processing there's no list to navigate either.
                if TransmutePanel.state?.mode == .customInput || TransmutePanel.state?.mode == .processing {
                    return Unmanaged.passRetained(event)
                }

                // Actions-list mode: navigation keys are swallowed so arrow /
                // return don't leak into the source app underneath.
                switch keyCode {
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
        processingTask?.cancel()
        processingTask = nil
        state = nil
        onActivate = nil
        panel?.close()
        panel = nil
    }

    /// Morphs the panel into the Siri-style "in progress" state, runs the
    /// transformation, then dismisses and pastes once it completes.
    private static func startProcessing(label: String, text: String, action: TextAction) {
        guard let state else { return }
        withAnimation(.easeOut(duration: 0.18)) {
            state.processingLabel = label
            state.mode = .processing
        }
        processingTask = Task {
            let result = await action.apply(to: text)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                dismiss()
                AccessibilityService.replaceSelectedText(with: result)
            }
        }
    }
}

// MARK: - Panel SwiftUI Content

struct PanelContentView: View {
    let selectedText: String
    let actions: [TextAction]
    @ObservedObject var state: PanelState
    let onAction: (TextAction) -> Void
    let onCustomSubmit: (String) -> Void

    var body: some View {
        Group {
            switch state.mode {
            case .customInput:
                CustomInputView(selectedText: selectedText, onSubmit: onCustomSubmit)
            case .processing:
                ProcessingView(label: state.processingLabel)
            case .actions:
                actionsList
            }
        }
        .frame(width: 560, height: 420)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        )
        .overlay {
            if state.mode == .processing {
                SiriBorderView()
            }
        }
        // Keyboard navigation is handled by the CGEvent tap in TransmutePanel,
        // so SwiftUI/AppKit focus rings on Buttons would just clash with our
        // own highlight. Kill them for the whole panel.
        .focusEffectDisabled()
    }

    private var actionsList: some View {
        VStack(spacing: 0) {
            // Preview of selected text — Spotlight-style "query" row
            HStack(spacing: 14) {
                Image("MenuBarIcon")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 22, height: 22)
                    .foregroundStyle(panelIconGradient)
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
                                        .foregroundStyle(panelIconGradient)
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

            HStack {
                Spacer()
                Text("↵ run   esc cancel")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 14)
            .padding(.top, 6)
        }
    }
}

private struct CustomInputView: View {
    let selectedText: String
    let onSubmit: (String) -> Void
    @State private var prompt = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Prompt row — like Spotlight's query field
            HStack(spacing: 14) {
                Image("MenuBarIcon")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 22, height: 22)
                    .foregroundStyle(panelIconGradient)
                TextField("Describe the transformation…", text: $prompt)
                    .font(.system(size: 22, weight: .regular))
                    .textFieldStyle(.plain)
                    .focused($focused)
                    .onSubmit { onSubmit(prompt) }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 18)

            Divider().opacity(0.4)

            // Reference: the selected text the prompt will operate on
            ScrollView {
                Text(selectedText)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.secondary)
                    .textSelection(.disabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(22)
            }

            Spacer(minLength: 0)

            HStack {
                Spacer()
                Text("↵ run   esc cancel")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 14)
        }
        .onAppear { focused = true }
    }
}

/// Siri-style "in progress" state — a breathing, slowly spinning gradient
/// orb with a shimmering label, shown while the transformation runs.
private struct ProcessingView: View {
    let label: String
    @State private var breathe = false
    @State private var spin = false
    @State private var shimmer = false

    var body: some View {
        VStack(spacing: 22) {
            ZStack {
                Circle()
                    .fill(panelIconGradient)
                    .frame(width: 110, height: 110)
                    .blur(radius: 30)
                    .opacity(0.85)
                Circle()
                    .fill(panelIconGradient)
                    .frame(width: 72, height: 72)
                    .blur(radius: 4)
            }
            .scaleEffect(breathe ? 1.12 : 0.86)
            .rotationEffect(.degrees(spin ? 360 : 0))
            .animation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true), value: breathe)
            .animation(.linear(duration: 3.4).repeatForever(autoreverses: false), value: spin)

            Text("\(label)…")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.secondary)
                .opacity(shimmer ? 0.45 : 1)
                .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: shimmer)
        }
        .frame(width: 560, height: 420)
        .onAppear {
            breathe = true
            spin = true
            shimmer = true
        }
    }
}

/// Animated gradient comet that travels around the panel's border while
/// processing, echoing macOS's Siri activation glow. Uses a dash pattern
/// sized to the panel's perimeter so the moving segment wraps seamlessly.
private struct SiriBorderView: View {
    private let cornerRadius: CGFloat = 18
    @State private var phase: CGFloat = 0

    private var borderGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0xA9 / 255.0, green: 0x33 / 255.0, blue: 0xFF / 255.0),
                Color(red: 0xB9 / 255.0, green: 0x44 / 255.0, blue: 0xD1 / 255.0),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private func perimeter(for size: CGSize) -> CGFloat {
        let straightWidth: CGFloat = 2 * (size.width - 2 * cornerRadius)
        let straightHeight: CGFloat = 2 * (size.height - 2 * cornerRadius)
        let corners: CGFloat = 2 * CGFloat.pi * cornerRadius
        return straightWidth + straightHeight + corners
    }

    private func style(perimeter: CGFloat, lineWidth: CGFloat) -> StrokeStyle {
        let comet: CGFloat = perimeter * 0.22
        let dash: [CGFloat] = [comet, perimeter - comet]
        return StrokeStyle(lineWidth: lineWidth, lineCap: .round, dash: dash, dashPhase: phase)
    }

    var body: some View {
        GeometryReader { geo in
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            let totalPerimeter = perimeter(for: geo.size)

            ZStack {
                shape.stroke(borderGradient, style: style(perimeter: totalPerimeter, lineWidth: 3))
                    .blur(radius: 6)
                    .opacity(0.9)
                shape.stroke(borderGradient, style: style(perimeter: totalPerimeter, lineWidth: 1.5))
            }
            .onAppear {
                withAnimation(.linear(duration: 2.6).repeatForever(autoreverses: false)) {
                    phase = -totalPerimeter
                }
            }
        }
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
        state: PanelState(count: TextAction.builtIn.count),
        onAction: { _ in },
        onCustomSubmit: { _ in }
    )
}
