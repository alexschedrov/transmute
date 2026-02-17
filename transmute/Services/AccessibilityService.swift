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

    static func getSelectedText() -> String? {
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

