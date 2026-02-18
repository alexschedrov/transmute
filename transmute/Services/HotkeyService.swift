//
//  HotkeyService.swift
//  transmute
//
//  Created by Alex Schedrov on 2/17/26.
//

import Cocoa

class HotkeyService {
    private var eventTap: CFMachPort?
    private let onTrigger: () -> Void

    // Default: ⌥⇧T for "Transmute"
    private let triggerKeyCode: UInt16 = 0x11  // 'T'
    private let triggerModifiers: CGEventFlags = [.maskAlternate, .maskShift]

    init(onTrigger: @escaping () -> Void) {
        self.onTrigger = onTrigger
    }

    func register(retryCount: Int = 0) {
        let eventMask = (1 << CGEventType.keyDown.rawValue)

        let userInfo = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { proxy, type, event, userInfo -> Unmanaged<CGEvent>? in
                guard let userInfo else { return Unmanaged.passRetained(event) }
                let service = Unmanaged<HotkeyService>.fromOpaque(userInfo).takeUnretainedValue()
                return service.handleEvent(type: type, event: event)
            },
            userInfo: userInfo
        ) else {
            if retryCount < 10 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.register(retryCount: retryCount + 1)
                }
            } else {
                print("⚠️ Failed to create event tap after retries. Check Accessibility permissions.")
            }
            return
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Re-enable if macOS disables the tap
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passRetained(event)
        }

        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags.intersection([.maskAlternate, .maskShift, .maskCommand, .maskControl])

        if keyCode == triggerKeyCode && flags == triggerModifiers {
            DispatchQueue.main.async { self.onTrigger() }
            return nil // swallow the event
        }

        return Unmanaged.passRetained(event)
    }
}

