import AppKit
import Combine
import Darwin
import SwiftUI

@main
struct ServiceStatusMenuApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    /// The window lives in MenuPanel.swift; the app needs one scene, so it has an empty one.
    var body: some Scene {
        Settings { EmptyView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var store: StatusStore?
    private var menu: MenuPanelController?
    private var watch: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if CommandLine.arguments.contains("--self-test") {
            exit(SelfTests.run())
        }
        NSApplication.shared.setActivationPolicy(.accessory)
        let store = StatusStore(autoStart: true)
        let menu = MenuPanelController { MenuBarContentView(store: store) }
        self.store = store
        self.menu = menu
        updateIcon()
        // objectWillChange fires before the change lands, so read the new state on the next turn.
        watch = store.objectWillChange.receive(on: RunLoop.main).sink { [weak self] _ in
            MainActor.assumeIsolated { self?.updateIcon() }
        }
    }

    private func updateIcon() {
        guard let store, let button = menu?.item.button else { return }
        let condition = store.overallCondition
        let image = NSImage(systemSymbolName: condition.menuBarSymbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(paletteColors: [NSColor(condition.color)]))
        image?.isTemplate = false
        button.image = image
        button.setAccessibilityLabel("Service status: \(condition.title)")
    }
}
