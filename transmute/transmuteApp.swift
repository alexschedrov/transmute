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
        MenuBarExtra("Transmute", image: "MenuBarIcon") {
            SettingsLink {
                Text("Settings")
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
    private var defaultsObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        KeychainService.migrateFromUserDefaultsIfNeeded()
        AccessibilityService.promptIfNeeded()

        hotkeyService = HotkeyService(shortcut: UserDefaults.standard.hotkeyShortcut) {
            TransmutePanel.show()
        }
        hotkeyService.register()

        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.hotkeyService.updateShortcut(UserDefaults.standard.hotkeyShortcut)
        }
    }
}
