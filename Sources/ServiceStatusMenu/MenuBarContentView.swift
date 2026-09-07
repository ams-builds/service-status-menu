import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var store: StatusStore

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if let error = store.configurationError {
                configurationError(error)
            }

            if store.services.isEmpty {
                emptyState
            } else {
                serviceList
            }

            Divider()
            footer
        }
        .frame(width: 390)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: store.overallCondition.symbolName)
                .font(.title2)
                .foregroundStyle(store.overallCondition.color)

            VStack(alignment: .leading, spacing: 2) {
                Text("Service Status")
                    .font(.headline)
                Text(headerSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if store.isRefreshing {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(14)
    }

    private var headerSubtitle: String {
        if store.isRefreshing {
            return "Checking services…"
        }
        if let lastRefresh = store.lastRefresh {
            return "Updated \(lastRefresh.formatted(.relative(presentation: .named)))"
        }
        return "Waiting for first check"
    }

    private static let estimatedRowHeight: CGFloat = 70
    private static let listMaxHeight: CGFloat = 430

    private var serviceList: some View {
        Group {
            if CGFloat(store.services.count) * Self.estimatedRowHeight > Self.listMaxHeight {
                ScrollView {
                    serviceRows
                }
                .frame(height: Self.listMaxHeight)
            } else {
                serviceRows
            }
        }
    }

    private var serviceRows: some View {
        LazyVStack(spacing: 0) {
            ForEach(store.services) { service in
                ServiceRow(
                    service: service,
                    status: store.status(for: service),
                    isRefreshing: store.isRefreshing
                )
                if service.id != store.services.last?.id {
                    Divider()
                        .padding(.leading, 46)
                }
            }
        }
    }

    private func configurationError(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(.orange.opacity(0.08))
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "list.bullet.rectangle")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No services loaded")
                .font(.headline)
            Text("Tap 🛠️ below to add a service.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
    }

    private var footer: some View {
        VStack(spacing: 8) {
            HStack {
                Text(store.refreshIntervalDescription)
                Spacer()
                if let url = store.configurationURL {
                    Text(url.lastPathComponent)
                        .help(url.path)
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Button {
                    Task { await store.refresh() }
                } label: {
                    Label("Refresh Now", systemImage: "arrow.clockwise")
                }
                .disabled(store.isRefreshing || store.configuration == nil)

                Button {
                    Task { await store.reloadConfiguration() }
                } label: {
                    Label("Reload Config", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(store.isRefreshing)

                Button {
                    store.openSettingsWindow()
                } label: {
                    Text("🛠️")
                }
                .buttonStyle(.plain)
                .help("Manage Services")

                Spacer()

                Menu {
                    Button("Open Configuration") {
                        store.openConfiguration()
                    }
                    Button("Show in Finder") {
                        store.revealConfiguration()
                    }
                    Divider()
                    Button("Quit Service Status") {
                        store.quit()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
        }
        .padding(12)
    }
}

private struct ServiceRow: View {
    let service: ServiceConfiguration
    let status: ServiceStatus?
    let isRefreshing: Bool

    private var condition: ServiceCondition {
        status?.condition ?? .unknown
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: condition.symbolName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(condition.color)
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(service.name)
                        .font(.body.weight(.medium))
                    Spacer()
                    Text(condition.title)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(condition.color)
                }

                Text(status?.message ?? (isRefreshing ? "Checking…" : "Not checked yet"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                if let status {
                    HStack(spacing: 8) {
                        Text(status.checkedAt, style: .time)
                        if let latency = status.responseTimeMilliseconds {
                            Text("\(latency) ms")
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Open \(service.name)") {
                NSWorkspace.shared.open(service.url)
            }
        }
    }
}
