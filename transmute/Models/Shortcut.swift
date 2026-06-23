//
//  Shortcut.swift
//  transmute
//

import Cocoa

struct Shortcut: Equatable {
    var keyCode: UInt16
    var modifiers: CGEventFlags
    var keyLabel: String

    // ⌥⇧T for "Transmute"
    static let `default` = Shortcut(keyCode: 0x11, modifiers: [.maskAlternate, .maskShift], keyLabel: "T")

    var displayString: String {
        var symbols = ""
        if modifiers.contains(.maskControl) { symbols += "⌃" }
        if modifiers.contains(.maskAlternate) { symbols += "⌥" }
        if modifiers.contains(.maskShift) { symbols += "⇧" }
        if modifiers.contains(.maskCommand) { symbols += "⌘" }
        return symbols + keyLabel
    }
}

extension UserDefaults {
    private static let keyCodeKey = "hotkeyKeyCode"
    private static let modifiersKey = "hotkeyModifiers"
    private static let keyLabelKey = "hotkeyKeyLabel"

    var hotkeyShortcut: Shortcut {
        guard object(forKey: Self.keyCodeKey) != nil else { return .default }
        let keyCode = UInt16(integer(forKey: Self.keyCodeKey))
        let modifiers = CGEventFlags(rawValue: UInt64(integer(forKey: Self.modifiersKey)))
        let keyLabel = string(forKey: Self.keyLabelKey) ?? Shortcut.default.keyLabel
        return Shortcut(keyCode: keyCode, modifiers: modifiers, keyLabel: keyLabel)
    }
}
