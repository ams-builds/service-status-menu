import SwiftUI

/// Hearth's layout, shared with the Orbi menu through Theme.swift: the heading scrolls with the
/// page and pins as a glass card at the top; the dock floats on glass at the bottom.
struct MenuBarContentView: View {
    enum Page { case status, manage }

    @ObservedObject var store: StatusStore
    @State private var page = Page.status

    private func count(_ condition: ServiceCondition) -> Int {
        store.services.filter { (store.status(for: $0)?.condition ?? .unknown) == condition }.count
    }

    var body: some View {
        ZStack {
            PanelBackground()
            GlassPage(eyebrow: eyebrow, title: page == .status ? "Services" : "Manage") {
                chips
            } content: {
                VStack(spacing: 8) {
                    if let error = store.configurationError {
                        Text("⚠️ " + error)
                            .font(.system(size: 12)).foregroundStyle(Theme.bad)
                            .padding(12).frame(maxWidth: .infinity, alignment: .leading).card(radius: 14)
                            .textSelection(.enabled)
                    }
                    if page == .status { statusPage } else { ManageView(store: store) }
                }
            }
        }
        .overlay(alignment: .bottom) { dock.padding(.bottom, 14) }
        .frame(width: Theme.panel.width, height: Theme.panel.height)
        .foregroundStyle(Theme.ink)
    }

    // MARK: Pages

    @ViewBuilder private var statusPage: some View {
        if store.services.isEmpty {
            Text("📭").font(.system(size: 28)).padding(.top, 24)
                .help("No services loaded. Open 🛠️ to add one.")
                .accessibilityLabel("No services loaded")
        } else {
            ForEach(store.services) { service in
                ServiceRow(service: service, status: store.status(for: service), isRefreshing: store.isRefreshing)
            }
        }
    }

    // MARK: Heading and dock

    private var chips: some View {
        HStack(spacing: 6) {
            CountChip(glyph: "✅", value: count(.operational), label: "Operational")
            CountChip(glyph: "⚠️", value: count(.degraded), label: "Degraded")
            CountChip(glyph: "🛑", value: count(.outage), label: "Outage")
        }
    }

    private var eyebrow: String {
        if store.isRefreshing { return "Service Status · ⏳" }
        if let last = store.lastRefresh { return "Service Status · 🔄 " + Self.clock.string(from: last) }
        return "Service Status"
    }

    private var dock: some View {
        Dock(pages: [DockPage(page: Page.status, glyph: "📋", help: "Services"),
                     DockPage(page: Page.manage, glyph: "🛠️", help: "Manage services")],
             selection: $page,
             actions: [
                DockAction(glyph: "🔄", help: "Refresh now", disabled: store.isRefreshing || store.configuration == nil, spins: true) {
                    Task { await store.refresh() }
                },
                DockAction(glyph: "📥", help: "Reload config") { Task { await store.reloadConfiguration() } },
                DockAction(glyph: "📂", help: "Show config in Finder") { store.revealConfiguration() },
                DockAction(glyph: "🚪", help: "Quit Service Status") { store.quit() }
             ])
    }

    private static let clock: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

/// Add and remove services inside the panel, so nothing opens in a separate window.
private struct ManageView: View {
    @ObservedObject var store: StatusStore
    @State private var newName = ""
    @State private var newURL = ""

    private var canAdd: Bool {
        !newName.trimmingCharacters(in: .whitespaces).isEmpty && !newURL.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func field(_ title: String, text: Binding<String>) -> some View {
        TextField(title, text: text)
            .textFieldStyle(.plain).font(.system(size: 13.5))
            .padding(.horizontal, 14).frame(height: 40)
            .background {
                let shape = RoundedRectangle(cornerRadius: 13, style: .continuous)
                shape.fill(Theme.field).overlay(shape.strokeBorder(Theme.fieldEdge, lineWidth: 0.75))
            }
    }

    var body: some View {
        VStack(spacing: 8) {
            VStack(spacing: 8) {
                field("Name", text: $newName)
                field("https://status.example.com", text: $newURL)
                HStack {
                    Spacer()
                    IconButton(glyph: "➕", help: "Add service") {
                        store.addService(name: newName, urlString: newURL)
                        if store.configurationError == nil { newName = ""; newURL = "" }
                    }
                    .disabled(!canAdd)
                    .opacity(canAdd ? 1 : 0.4)
                }
            }
            .padding(12).card(radius: 16)

            ForEach(store.services) { service in
                HStack(spacing: 12) {
                    IconPlate(glyph: "🌐", label: service.name)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(service.name).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.fg).lineLimit(1)
                        Text(service.url.absoluteString).font(.system(size: 11)).foregroundStyle(Theme.muted).lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    IconButton(glyph: "🗑️", help: "Remove \(service.name)") { store.removeService(id: service.id) }
                }
                .padding(.horizontal, 10).padding(.vertical, 8)
                .card(radius: 16)
            }
        }
    }
}

private struct ServiceRow: View {
    let service: ServiceConfiguration
    let status: ServiceStatus?
    let isRefreshing: Bool

    private var condition: ServiceCondition { status?.condition ?? .unknown }

    private var tone: Color {
        switch condition {
        case .operational, .unknown: Theme.muted
        case .degraded: Theme.warn
        case .outage: Theme.bad
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            IconPlate(glyph: condition.emoji, label: condition.title)
            VStack(alignment: .leading, spacing: 2) {
                Text(service.name).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.fg).lineLimit(1)
                Text(status?.message ?? (isRefreshing ? "⏳" : "—"))
                    .font(.system(size: 11)).foregroundStyle(tone).lineLimit(2)
            }
            Spacer(minLength: 4)
            if let status {
                VStack(alignment: .trailing, spacing: 3) {
                    Text(status.responseTimeMilliseconds.map { "\($0) ms" } ?? " ")
                        .font(.system(size: 13, weight: .semibold)).monospacedDigit().foregroundStyle(Theme.fg)
                    Text(status.checkedAt, style: .time)
                        .font(.system(size: 10)).monospacedDigit().foregroundStyle(Theme.faint)
                }
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .card(radius: 16)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Open \(service.name)") { NSWorkspace.shared.open(service.url) }
        }
        .help(condition.title)
    }
}
