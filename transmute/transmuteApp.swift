//
//  transmuteApp.swift
//  transmute
//
//  Created by Alex Schedrov on 2/17/26.
//

import SwiftUI

@main
struct transmuteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("Transmute", systemImage: "textformat.alt") {
            SettingsLink {
                Text("Settings…")
            }
            .keyboardShortcut(",")
            Divider()
            Button("Quit Transmute") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        Settings {
            SettingsView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var hotkeyService: HotkeyService!

    func applicationDidFinishLaunching(_ notification: Notification) {
        AccessibilityService.promptIfNeeded()

        hotkeyService = HotkeyService {
            TransmutePanel.show()
        }
        hotkeyService.register()
    }
}
