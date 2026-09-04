import Foundation

struct StatusChecker: Sendable {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func check(
        _ service: ServiceConfiguration,
        defaultTimeout: TimeInterval
    ) async -> ServiceStatus {
        let startedAt = ContinuousClock.now
        let checkedAt = Date()

        do {
            let result: (ServiceCondition, String)
            switch service.type {
            case .statuspage:
                result = try await checkStatuspage(service, defaultTimeout: defaultTimeout)
            case .http:
                result = try await checkHTTP(service, defaultTimeout: defaultTimeout)
            case .json:
                result = try await checkJSON(service, defaultTimeout: defaultTimeout)
            }

            return ServiceStatus(
                serviceID: service.id,
                condition: result.0,
                message: result.1,
                checkedAt: checkedAt,
                responseTimeMilliseconds: Self.elapsedMilliseconds(since: startedAt)
            )
        } catch is CancellationError {
            return ServiceStatus(
                serviceID: service.id,
                condition: .unknown,
                message: "Check cancelled",
                checkedAt: checkedAt,
                responseTimeMilliseconds: nil
            )
        } catch {
            return ServiceStatus(
                serviceID: service.id,
                condition: .unknown,
                message: Self.friendlyErrorMessage(error),
                checkedAt: checkedAt,
                responseTimeMilliseconds: Self.elapsedMilliseconds(since: startedAt)
            )
        }
    }

    static func statuspageEndpoint(for baseURL: URL) -> URL? {
        if baseURL.path.hasSuffix("/api/v2/summary.json") {
            return baseURL
        }

        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            return nil
        }

        var path = components.path
        while path.hasSuffix("/") {
            path.removeLast()
        }
        components.path = path + "/api/v2/summary.json"
        components.query = nil
        components.fragment = nil
        return components.url
    }

    static func condition(forStatuspageIndicator indicator: String) -> ServiceCondition {
        switch indicator.lowercased() {
        case "none": .operational
        case "minor": .degraded
        case "major", "critical": .outage
        default: .unknown
        }
    }

    private func checkStatuspage(
        _ service: ServiceConfiguration,
        defaultTimeout: TimeInterval
    ) async throws -> (ServiceCondition, String) {
        guard let endpoint = Self.statuspageEndpoint(for: service.url) else {
            throw CheckError.invalidURL
        }

        let (data, response) = try await request(
            endpoint,
            timeout: service.timeoutSeconds ?? defaultTimeout
        )
        try Self.requireSuccessfulResponse(response)

        let summary = try JSONDecoder().decode(StatuspageSummary.self, from: data)
        let condition = Self.condition(forStatuspageIndicator: summary.status.indicator)
        let message = summary.incidents.first?.name ?? summary.status.description
        return (condition, message)
    }

    private func checkHTTP(
        _ service: ServiceConfiguration,
        defaultTimeout: TimeInterval
    ) async throws -> (ServiceCondition, String) {
        let (_, response) = try await request(
            service.url,
            timeout: service.timeoutSeconds ?? defaultTimeout
        )
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CheckError.nonHTTPResponse
        }

        let expected = service.expectedStatus
        let healthy = expected.map { httpResponse.statusCode == $0 }
            ?? (200...299).contains(httpResponse.statusCode)

        if healthy {
            return (.operational, "HTTP \(httpResponse.statusCode)")
        }
        return (.outage, "Unexpected HTTP \(httpResponse.statusCode)")
    }

    private func checkJSON(
        _ service: ServiceConfiguration,
        defaultTimeout: TimeInterval
    ) async throws -> (ServiceCondition, String) {
        let (data, response) = try await request(
            service.url,
            timeout: service.timeoutSeconds ?? defaultTimeout
        )
        try Self.requireSuccessfulResponse(response)

        guard let path = service.jsonPath, let expected = service.expectedValue else {
            throw CheckError.invalidJSONConfiguration
        }

        let root = try JSONSerialization.jsonObject(with: data)
        guard let value = Self.value(at: path, in: root) else {
            return (.outage, "JSON path ‘\(path)’ was not found")
        }

        let actual = Self.stringValue(value)
        if actual.caseInsensitiveCompare(expected) == .orderedSame {
            return (.operational, "\(path) = \(actual)")
        }
        return (.outage, "Expected \(expected), received \(actual)")
    }

    private func request(_ url: URL, timeout: TimeInterval) async throws -> (Data, URLResponse) {
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "GET"
        request.setValue("ServiceStatusMenu/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        return try await session.data(for: request)
    }

    private static func requireSuccessfulResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CheckError.nonHTTPResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw CheckError.httpStatus(httpResponse.statusCode)
        }
    }

    static func value(at path: String, in root: Any) -> Any? {
        var current: Any = root
        for component in path.split(separator: ".").map(String.init) {
            if let dictionary = current as? [String: Any], let next = dictionary[component] {
                current = next
            } else if let array = current as? [Any],
                      let index = Int(component),
                      array.indices.contains(index) {
                current = array[index]
            } else {
                return nil
            }
        }
        return current
    }

    private static func stringValue(_ value: Any) -> String {
        if let string = value as? String {
            return string
        }
        if let number = value as? NSNumber {
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return number.boolValue ? "true" : "false"
            }
            return number.stringValue
        }
        return String(describing: value)
    }

    private static func elapsedMilliseconds(
        since instant: ContinuousClock.Instant
    ) -> Int {
        let duration = instant.duration(to: .now)
        let components = duration.components
        let milliseconds = (components.seconds * 1_000)
            + (components.attoseconds / 1_000_000_000_000_000)
        return Int(milliseconds)
    }

    private static func friendlyErrorMessage(_ error: Error) -> String {
        if let localized = error as? LocalizedError,
           let description = localized.errorDescription {
            return description
        }
        return error.localizedDescription
    }
}

private struct StatuspageSummary: Decodable {
    let status: Status
    let incidents: [Incident]

    struct Status: Decodable {
        let indicator: String
        let description: String
    }

    struct Incident: Decodable {
        let name: String
    }
}

private enum CheckError: LocalizedError {
    case invalidURL
    case nonHTTPResponse
    case httpStatus(Int)
    case invalidJSONConfiguration

    var errorDescription: String? {
        switch self {
        case .invalidURL: "Could not construct the status endpoint URL"
        case .nonHTTPResponse: "The server returned a non-HTTP response"
        case .httpStatus(let code): "The server returned HTTP \(code)"
        case .invalidJSONConfiguration: "The JSON check is missing json_path or expected_value"
        }
    }
}
