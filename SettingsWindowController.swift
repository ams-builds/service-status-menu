import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSObject {
    static let shared = SettingsWindowController()

    private var window: NSWindow?

    func show(store: StatusStore) {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hosting = NSHostingController(rootView: SettingsView(store: store))
        let newWindow = NSWindow(contentViewController: hosting)
        newWindow.title = "Manage Services"
        newWindow.styleMask = [.titled, .closable]
        newWindow.isReleasedWhenClosed = false
        newWindow.center()
        window = newWindow

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: newWindow,
            queue: .main
        ) { [weak self] _ in
            self?.window = nil
        }

        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
