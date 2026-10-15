import SwiftUI

/// Same layout language as the Orbi menu: near-black base, emoji plates, hairline cards, 400 x 660.
struct MenuBarContentView: View {
    @ObservedObject var store: StatusStore
    @State private var spin = 0.0

    private func count(_ condition: ServiceCondition) -> Int {
        store.services.filter { (store.status(for: $0)?.condition ?? .unknown) == condition }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if let error = store.configurationError {
                Text("⚠️ " + error)
                    .font(.system(size: 12)).foregroundStyle(Theme.bad)
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading).card(radius: 14)
                    .textSelection(.enabled)
            }
            stats
            if store.services.isEmpty {
                Text("📭").font(.system(size: 28)).padding(.top, 24)
                    .frame(maxWidth: .infinity)
                    .help("No services loaded. Tap 🛠️ to add one.")
                    .accessibilityLabel("No services loaded")
                    .frame(maxHeight: .infinity, alignment: .top)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(store.services) { service in
                            ServiceRow(service: service, status: store.status(for: service), isRefreshing: store.isRefreshing)
                        }
                    }
                }
                .frame(maxHeight: .infinity)
            }
            footer
        }
        .padding(16)
        .frame(width: 400, height: 660, alignment: .top)
        .background(Theme.base)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            IconPlate(glyph: store.overallCondition.emoji, label: store.overallCondition.title, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text("Service Status")
                    .font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.fg)
                Text(headerDetail).font(.system(size: 12)).foregroundStyle(Theme.muted).lineLimit(1)
            }
            Spacer()
            IconButton(glyph: "🛠️", help: "Manage services") { store.openSettingsWindow() }
            IconButton(glyph: "🔄", help: "Refresh now") {
                withAnimation(.easeInOut(duration: 0.6)) { spin += 360 }
                Task { await store.refresh() }
            }
            .rotationEffect(.degrees(spin))
            .disabled(store.isRefreshing || store.configuration == nil)
        }
    }

    private var headerDetail: String {
        if store.isRefreshing { return "⏳" }
        if let last = store.lastRefresh { return "🔄 " + Self.clock.string(from: last) + " · ⏱️ " + store.refreshIntervalDescription }
        return "—"
    }

    // MARK: Counts

    private var stats: some View {
        HStack(spacing: 10) {
            stat(count(.operational), "✅", "Operational", Theme.good)
            stat(count(.degraded), "⚠️", "Degraded", count(.degraded) == 0 ? Theme.fg : Theme.warn)
            stat(count(.outage), "🛑", "Outage", count(.outage) == 0 ? Theme.fg : Theme.bad)
        }
    }

    private func stat(_ value: Int, _ glyph: String, _ label: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(glyph).font(.system(size: 16))
            Text("\(value)").font(.system(size: 26, weight: .bold)).monospacedDigit().foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14).padding(.vertical, 12)
        .card(radius: 16)
        .help(label)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)")
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            IconButton(glyph: "📥", help: "Reload config") { Task { await store.reloadConfiguration() } }
                .disabled(store.isRefreshing)
            IconButton(glyph: "📂", help: "Show config in Finder") { store.revealConfiguration() }
            Spacer()
            IconButton(glyph: "🚪", help: "Quit Service Status") { store.quit() }
        }
    }

    private static let clock: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

private struct ServiceRow: View {
    let service: ServiceConfiguration
    let status: ServiceStatus?
    let isRefreshing: Bool

    private var condition: ServiceCondition { status?.condition ?? .unknown }

    private var tone: Color {
        switch condition {
        case .operational: Theme.muted
        case .degraded: Theme.warn
        case .outage: Theme.bad
        case .unknown: Theme.muted
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
