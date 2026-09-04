import Foundation

/// A small dependency-free verification harness for environments where the
/// Xcode XCTest runtime is not installed. Run with:
/// `swift run ServiceStatusMenu --self-test`
enum SelfTests {
    static func run() -> Int32 {
        var failures: [String] = []

        run("starter configuration", failures: &failures) {
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
            let url = directory.appendingPathComponent("services.yaml")
            let loader = ConfigurationLoader(environment: [:])
            defer { try? FileManager.default.removeItem(at: directory) }

            let created = try loader.createStarterConfigurationIfNeeded(at: url)
            try require(created, "starter file was not created")
            let configuration = try loader.load(from: url)
            try require(configuration.pollIntervalSeconds == 300, "wrong default polling interval")
            try require(configuration.services.count == 5, "wrong starter service count")
            try require(configuration.services.first?.name == "GitHub", "first starter service is incorrect")
        }

        run("legacy status_url format", failures: &failures) {
            let yaml = """
            services:
              - name: Example
                status_url: https://status.example.com
            """
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
            let url = directory.appendingPathComponent("services.yaml")
            defer { try? FileManager.default.removeItem(at: directory) }

            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try yaml.write(to: url, atomically: true, encoding: .utf8)
            let configuration = try ConfigurationLoader(environment: [:]).load(from: url)
            try require(configuration.services.first?.type == .statuspage, "default type is not statuspage")
            try require(
                configuration.services.first?.url.absoluteString == "https://status.example.com",
                "status_url was not decoded"
            )
        }

        run("Statuspage endpoint and indicators", failures: &failures) {
            let base = URL(string: "https://status.example.com/")!
            let endpoint = StatusChecker.statuspageEndpoint(for: base)
            try require(
                endpoint?.absoluteString == "https://status.example.com/api/v2/summary.json",
                "summary endpoint was constructed incorrectly"
            )
            try require(StatusChecker.condition(forStatuspageIndicator: "none") == .operational, "none mapping")
            try require(StatusChecker.condition(forStatuspageIndicator: "minor") == .degraded, "minor mapping")
            try require(StatusChecker.condition(forStatuspageIndicator: "major") == .outage, "major mapping")
            try require(StatusChecker.condition(forStatuspageIndicator: "critical") == .outage, "critical mapping")
            try require(StatusChecker.condition(forStatuspageIndicator: "other") == .unknown, "fallback mapping")
        }

        run("nested JSON paths", failures: &failures) {
            let root: [String: Any] = [
                "checks": [
                    ["status": "healthy"],
                    ["status": "degraded"]
                ]
            ]
            let value = StatusChecker.value(at: "checks.1.status", in: root) as? String
            try require(value == "degraded", "nested array path did not resolve")
            try require(StatusChecker.value(at: "checks.2.status", in: root) == nil, "missing path did not return nil")
        }

        run("polling interval validation", failures: &failures) {
            let configuration = AppConfiguration(
                pollIntervalSeconds: 5,
                services: [
                    ServiceConfiguration(
                        name: "Example",
                        url: URL(string: "https://status.example.com")!
                    )
                ]
            )
            do {
                _ = try configuration.validated()
                throw SelfTestError.failed("unsafe polling interval was accepted")
            } catch is ConfigurationError {
                // Expected.
            }
        }

        if failures.isEmpty {
            print("Self-test passed: 5 groups")
            return 0
        }

        fputs("Self-test failed:\n", stderr)
        for failure in failures {
            fputs("- \(failure)\n", stderr)
        }
        return 1
    }

    private static func run(
        _ name: String,
        failures: inout [String],
        operation: () throws -> Void
    ) {
        do {
            try operation()
            print("PASS: \(name)")
        } catch {
            failures.append("\(name): \(error.localizedDescription)")
        }
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        guard condition() else {
            throw SelfTestError.failed(message)
        }
    }
}

private enum SelfTestError: LocalizedError {
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .failed(let message): message
        }
    }
}
