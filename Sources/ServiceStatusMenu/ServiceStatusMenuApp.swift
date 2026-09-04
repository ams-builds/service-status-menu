import AppKit
import Darwin
import SwiftUI

@main
struct ServiceStatusMenuApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store: StatusStore

    init() {
        let isSelfTest = CommandLine.arguments.contains("--self-test")
        _store = StateObject(wrappedValue: StatusStore(autoStart: !isSelfTest))
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(store: store)
        } label: {
            Image(systemName: store.overallCondition.menuBarSymbolName)
                .symbolRenderingMode(.palette)
                .foregroundStyle(store.overallCondition.color)
                .accessibilityLabel("Service status: \(store.overallCondition.title)")
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if CommandLine.arguments.contains("--self-test") {
            exit(SelfTests.run())
        }
        NSApplication.shared.setActivationPolicy(.accessory)
    }
}
