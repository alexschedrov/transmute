//
//  AccessibilityService.swift
//  transmute
//
//  Created by Alex Schedrov on 2/17/26.
//

import Cocoa
import ApplicationServices

enum AccessibilityService {

    static func promptIfNeeded() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(opts)
    }

    static func getSelectedText() async -> String? {
        // Try AX API first (non-destructive, doesn't touch clipboard)
        if let text = getSelectedTextViaAX() {
            return text
        }
        // Fall back to ⌘C for apps that don't support AX selected text
        return await getSelectedTextViaClipboard()
    }

    private static func getSelectedTextViaAX() -> String? {
        let systemWide = AXUIElementCreateSystemWide()

        var focusedElement: AnyObject?
        guard AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        ) == .success else { return nil }

        var selectedText: AnyObject?
        guard AXUIElementCopyAttributeValue(
            focusedElement as! AXUIElement,
            kAXSelectedTextAttribute as CFString,
            &selectedText
        ) == .success else { return nil }

        let text = selectedText as? String
        return (text?.isEmpty == false) ? text : nil
    }

    private static func getSelectedTextViaClipboard() async -> String? {
        let pasteboard = NSPasteboard.general
        let previousContents = pasteboard.string(forType: .string)
        let previousChangeCount = pasteboard.changeCount

        // Simulate ⌘C with a clean event source
        let source = CGEventSource(stateID: .privateState)
        let cKeyCode: UInt16 = 0x08

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: cKeyCode, keyDown: true)
        keyDown?.flags = .maskCommand
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: cKeyCode, keyDown: false)
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cgSessionEventTap)
        keyUp?.post(tap: .cgSessionEventTap)

        // Poll for clipboard change without blocking the run loop
        for _ in 0..<10 {
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
            if pasteboard.changeCount != previousChangeCount { break }
        }

        guard pasteboard.changeCount != previousChangeCount else { return nil }

        let text = pasteboard.string(forType: .string)

        // Restore previous clipboard
        pasteboard.clearContents()
        if let old = previousContents {
            pasteboard.setString(old, forType: .string)
        }

        return (text?.isEmpty == false) ? text : nil
    }

    static func replaceSelectedText(with newText: String) {
        let pasteboard = NSPasteboard.general
        let previousContents = pasteboard.string(forType: .string)

        pasteboard.clearContents()
        pasteboard.setString(newText, forType: .string)

        // Simulate ⌘V
        let source = CGEventSource(stateID: .hidSystemState)
        let vKeyCode: UInt16 = 0x09

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true)
        keyDown?.flags = .maskCommand
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false)
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cgSessionEventTap)
        keyUp?.post(tap: .cgSessionEventTap)

        // Restore clipboard after paste completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let old = previousContents {
                pasteboard.clearContents()
                pasteboard.setString(old, forType: .string)
            }
        }
    }
}
