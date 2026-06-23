//
//  ShortcutRecorderView.swift
//  transmute
//

import SwiftUI

struct ShortcutRecorderView: View {
    let shortcut: Shortcut
    let onChange: (Shortcut) -> Void

    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        Button {
            isRecording ? stopRecording() : startRecording()
        } label: {
            Text(isRecording ? "Press a key…" : shortcut.displayString)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .frame(minWidth: 64)
                .background(isRecording ? AnyShapeStyle(Color.accentColor.opacity(0.2)) : AnyShapeStyle(.quaternary))
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .onDisappear(perform: stopRecording)
    }

    private func startRecording() {
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { // Escape cancels without changing the shortcut
                stopRecording()
                return nil
            }

            let modifiers = cgFlags(from: event.modifierFlags)
            guard !modifiers.isEmpty else { return event } // require at least one modifier; let other key presses through

            onChange(Shortcut(
                keyCode: event.keyCode,
                modifiers: modifiers,
                keyLabel: (event.charactersIgnoringModifiers ?? "").uppercased()
            ))
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        isRecording = false
    }

    private func cgFlags(from flags: NSEvent.ModifierFlags) -> CGEventFlags {
        var result: CGEventFlags = []
        if flags.contains(.control) { result.insert(.maskControl) }
        if flags.contains(.option) { result.insert(.maskAlternate) }
        if flags.contains(.shift) { result.insert(.maskShift) }
        if flags.contains(.command) { result.insert(.maskCommand) }
        return result
    }
}
