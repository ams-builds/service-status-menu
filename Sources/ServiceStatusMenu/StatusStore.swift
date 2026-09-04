import AppKit
import Foundation

@MainActor
final class StatusStore: ObservableObject {
    @Published private(set) var configuration: AppConfiguration?
    @Published private(set) var configurationURL: URL?
    @Published private(set) var statuses: [String: ServiceStatus] = [:]
    @Published private(set) var isRefreshing = false
    @Published private(set) var configurationError: String?
    @Published private(set) var lastRefresh: Date?

    private let loader: ConfigurationLoader
    private let checker: StatusChecker
    private var pollingTask: Task<Void, Never>?

    init(
        loader: ConfigurationLoader = ConfigurationLoader(),
        checker: StatusChecker = StatusChecker(),
        autoStart: Bool = true
    ) {
        self.loader = loader
        self.checker = checker

        if autoStart {
            Task { [weak self] in
                await self?.start()
            }
        }
    }

    var services: [ServiceConfiguration] {
        configuration?.services ?? []
    }

    var overallCondition: ServiceCondition {
        guard !services.isEmpty else {
            return .unknown
        }

        let current = services.compactMap { statuses[$0.id]?.condition }
        if current.contains(.outage) { return .outage }
        if current.contains(.degraded) { return .degraded }
        if current.count != services.count || current.contains(.unknown) { return .unknown }
        return .operational
    }

    var refreshIntervalDescription: String {
        guard let seconds = configuration?.pollIntervalSeconds else {
            return "Not configured"
        }
        if seconds.truncatingRemainder(dividingBy: 60) == 0 {
            let minutes = Int(seconds / 60)
            return "Every \(minutes) min"
        }
        return "Every \(Int(seconds)) sec"
    }

    func start() async {
        guard pollingTask == nil else { return }
        await reloadConfiguration()

        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let interval = max(self.configuration?.pollIntervalSeconds ?? 300, 15)
                do {
                    try await Task.sleep(for: .seconds(interval))
                } catch {
                    return
                }
                await self.refresh()
            }
        }
    }

    func reloadConfiguration() async {
        do {
            let url = try loader.defaultConfigurationURL()
            configurationURL = url
            try loader.createStarterConfigurationIfNeeded(at: url)
            let loaded = try loader.load(from: url)
            configuration = loaded
            configurationError = nil

            let validIDs = Set(loaded.services.map(\.id))
            statuses = statuses.filter { validIDs.contains($0.key) }
            await refresh()
        } catch {
            configurationError = error.localizedDescription
        }
    }

    func refresh() async {
        guard let configuration, !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        let checker = self.checker
        let defaultTimeout = configuration.requestTimeoutSeconds
        let services = configuration.services

        let results = await withTaskGroup(
            of: ServiceStatus.self,
            returning: [ServiceStatus].self
        ) { group in
            for service in services {
                group.addTask {
                    await checker.check(service, defaultTimeout: defaultTimeout)
                }
            }

            var values: [ServiceStatus] = []
            for await result in group {
                values.append(result)
            }
            return values
        }

        for result in results {
            statuses[result.serviceID] = result
        }
        lastRefresh = Date()
    }

    func status(for service: ServiceConfiguration) -> ServiceStatus? {
        statuses[service.id]
    }

    func openConfiguration() {
        guard let configurationURL else { return }
        NSWorkspace.shared.open(configurationURL)
    }

    func revealConfiguration() {
        guard let configurationURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([configurationURL])
    }

    func quit() {
        NSApplication.shared.terminate(nil)
    }
}
