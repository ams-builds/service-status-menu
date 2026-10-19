import AppKit
import SwiftUI

// The menu bar window, built the way Hearth (https://github.com/obileonardo/hearth-macos, MIT,
// Copyright (c) 2026 Elvis Obi; full notice in Theme.swift) builds its own: a clear, borderless
// panel under the menu bar icon. The system menu bar window has its own glass and frame, and the
// page's glass inside it went dull; in a clear panel the glass only sees the page behind it.
//
// This same file is used by Service Status and the Orbi menu. Change it in one, copy it to the other.

@MainActor
final class MenuPanelController: NSObject {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let panel: MenuPanel
    private var localMonitor: Any?
    private var globalMonitor: Any?

    init<Content: View>(@ViewBuilder content: () -> Content) {
        panel = MenuPanel(contentRect: NSRect(origin: .zero, size: Theme.panel),
                          styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        super.init()
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .popUpMenu
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.transient, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: content()
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.fg.opacity(0.12), lineWidth: 0.5))
            .modifier(NoFocusRing()))
        panel.onCancel = { [weak self] in self?.close() }
        item.button?.target = self
        item.button?.action = #selector(toggle)
    }

    @objc private func toggle() {
        if panel.isVisible { close() } else { open() }
    }

    func open() {
        guard let button = item.button, let window = button.window, let screen = window.screen ?? NSScreen.main else { return }
        let anchor = window.convertToScreen(button.convert(button.bounds, to: nil))
        let visible = screen.visibleFrame
        let size = Theme.panel
        let x = min(max(anchor.midX - size.width / 2, visible.minX + 8), visible.maxX - size.width - 8)
        let y = min(anchor.minY, visible.maxY) - size.height - 6
        panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
        panel.makeKeyAndOrderFront(nil)
        button.highlight(true)
        installDismissal()
    }

    func close() {
        panel.orderOut(nil)
        item.button?.highlight(false)
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        localMonitor = nil
        globalMonitor = nil
    }

    /// Closes on a click outside the panel or in another app, as Hearth does. Clicks on the
    /// icon are left to `toggle`, and native pop-up menus (right-click menus) belong to the panel.
    private func installDismissal() {
        guard localMonitor == nil else { return }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            MainActor.assumeIsolated {
                guard let self else { return }
                let mouse = NSEvent.mouseLocation
                let inPanel = self.panel.frame.contains(mouse)
                let onIcon = self.item.button?.window?.frame.contains(mouse) == true
                let nativeMenu = event.window.map { $0 !== self.panel && $0.level.rawValue >= NSWindow.Level.popUpMenu.rawValue } ?? true
                if !inPanel && !onIcon && !nativeMenu { self.close() }
            }
            return event
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.close() }
        }
    }
}

/// The panel takes keys (for the text fields), so macOS draws a blue ring on the first button.
/// Hearth's buttons show no ring; the lens already marks the selected page.
private struct NoFocusRing: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 14, *) { content.focusEffectDisabled() } else { content }
    }
}

private final class MenuPanel: NSPanel {
    var onCancel: () -> Void = {}
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    /// Esc closes the panel.
    override func cancelOperation(_ sender: Any?) { onCancel() }
}
