import SwiftUI

/// Same layout language as the Orbi menu: near-black base, emoji plates, hairline cards, 400 x 660.
/// The title bar and the dock float on glass above the page, so the page scrolls underneath them.
struct MenuBarContentView: View {
    enum Page { case status, manage }

    @ObservedObject var store: StatusStore
    @State private var page = Page.status
    @State private var spin = 0.0

    private func count(_ condition: ServiceCondition) -> Int {
        store.services.filter { (store.status(for: $0)?.condition ?? .unknown) == condition }.count
    }

    var body: some View {
        ZStack(alignment: .top) {
            Theme.base

            ScrollView {
                VStack(spacing: 8) {
                    if let error = store.configurationError {
                        Text("⚠️ " + error)
                            .font(.system(size: 12)).foregroundStyle(Theme.bad)
                            .padding(12).frame(maxWidth: .infinity, alignment: .leading).card(radius: 14)
                            .textSelection(.enabled)
                    }
                    if page == .status { statusPage } else { ManageView(store: store) }
                }
                .padding(.horizontal, 16)
                .padding(.top, 92)
                .padding(.bottom, 88)
            }

            header.padding(.horizontal, 12).padding(.top, 12)

            VStack {
                Spacer()
                dock.padding(.bottom, 14)
            }
        }
        .frame(width: 400, height: 660)
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

    // MARK: Floating chrome

    private var header: some View {
        HStack(spacing: 12) {
            Text(store.overallCondition.emoji).font(.system(size: 26))
                .help(store.overallCondition.title)
                .accessibilityLabel(store.overallCondition.title)
            VStack(alignment: .leading, spacing: 2) {
                Text("Service Status")
                    .font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.fg)
                Text(headerDetail).font(.system(size: 11)).foregroundStyle(Theme.muted).lineLimit(1)
            }
            Spacer()
            HStack(spacing: -6) {
                chip("✅", count(.operational))
                chip("⚠️", count(.degraded))
                chip("🛑", count(.outage))
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .glassBar(radius: 22)
    }

    private var headerDetail: String {
        if store.isRefreshing { return "⏳" }
        if let last = store.lastRefresh { return "🔄 " + Self.clock.string(from: last) + " · ⏱️ " + store.refreshIntervalDescription }
        return "—"
    }

    private func chip(_ glyph: String, _ value: Int) -> some View {
        HStack(spacing: 3) {
            Text(glyph).font(.system(size: 12))
            Text("\(value)").font(.system(size: 12, weight: .semibold)).monospacedDigit().foregroundStyle(Theme.fg)
        }
        .padding(.horizontal, 9).frame(height: 28)
        .background(Capsule().fill(Theme.base.opacity(0.55)))
        .padding(.leading, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(glyph) \(value)")
    }

    private var dock: some View {
        HStack(spacing: 2) {
            DockTab(glyph: "📋", help: "Services", selected: page == .status) {
                withAnimation(.spring(response: 0.4, dampingFraction: 1)) { page = .status }
            }
            DockTab(glyph: "🛠️", help: "Manage services", selected: page == .manage) {
                withAnimation(.spring(response: 0.4, dampingFraction: 1)) { page = .manage }
            }
            Rectangle().fill(Theme.hairline).frame(width: 1, height: 22).padding(.horizontal, 4)
            DockTab(glyph: "🔄", help: "Refresh now") {
                withAnimation(.easeInOut(duration: 0.6)) { spin += 360 }
                Task { await store.refresh() }
            }
            .rotationEffect(.degrees(spin))
            .disabled(store.isRefreshing || store.configuration == nil)
            DockTab(glyph: "📥", help: "Reload config") { Task { await store.reloadConfiguration() } }
            DockTab(glyph: "📂", help: "Show config in Finder") { store.revealConfiguration() }
            DockTab(glyph: "🚪", help: "Quit Service Status") { store.quit() }
        }
        .padding(6)
        .glassPill()
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
            .textFieldStyle(.plain).font(.system(size: 13))
            .padding(.horizontal, 10).frame(height: 30)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Theme.hover))
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
