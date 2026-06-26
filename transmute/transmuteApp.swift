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
            Button("Analytics…") {
                appDelegate.openAnalyticsWindow()
            }
            .keyboardShortcut("a")
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

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var hotkeyService: HotkeyService!
    private var defaultsObserver: NSObjectProtocol?
    private var analyticsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = AnalyticsService.shared  // warm singleton on main thread
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

    func openAnalyticsWindow() {
        if let w = analyticsWindow, w.isVisible {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let controller = NSHostingController(rootView: AnalyticsView())
        let window = NSWindow(contentViewController: controller)
        window.title = "Transmute Analytics"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.isReleasedWhenClosed = false
        window.center()
        window.delegate = self
        analyticsWindow = window
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        guard (notification.object as? NSWindow) === analyticsWindow else { return }
        let hasOtherRegularWindow = NSApp.windows.contains {
            $0 !== analyticsWindow && $0.isVisible && $0.styleMask.contains(.titled)
        }
        if !hasOtherRegularWindow {
            NSApp.setActivationPolicy(.prohibited)
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
