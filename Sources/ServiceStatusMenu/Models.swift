import Foundation
import SwiftUI

struct AppConfiguration: Codable, Equatable, Sendable {
    var pollIntervalSeconds: TimeInterval
    var requestTimeoutSeconds: TimeInterval
    var services: [ServiceConfiguration]

    enum CodingKeys: String, CodingKey {
        case pollIntervalSeconds = "poll_interval_seconds"
        case requestTimeoutSeconds = "request_timeout_seconds"
        case services
    }

    init(
        pollIntervalSeconds: TimeInterval = 300,
        requestTimeoutSeconds: TimeInterval = 10,
        services: [ServiceConfiguration]
    ) {
        self.pollIntervalSeconds = pollIntervalSeconds
        self.requestTimeoutSeconds = requestTimeoutSeconds
        self.services = services
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        pollIntervalSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .pollIntervalSeconds) ?? 300
        requestTimeoutSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .requestTimeoutSeconds) ?? 10
        services = try container.decode([ServiceConfiguration].self, forKey: .services)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(pollIntervalSeconds, forKey: .pollIntervalSeconds)
        try container.encode(requestTimeoutSeconds, forKey: .requestTimeoutSeconds)
        try container.encode(services, forKey: .services)
    }

    func validated() throws -> AppConfiguration {
        guard pollIntervalSeconds >= 15 else {
            throw ConfigurationError.invalidValue("poll_interval_seconds must be at least 15 seconds")
        }
        guard requestTimeoutSeconds > 0 else {
            throw ConfigurationError.invalidValue("request_timeout_seconds must be greater than zero")
        }
        guard !services.isEmpty else {
            throw ConfigurationError.invalidValue("services must contain at least one service")
        }

        var identifiers = Set<String>()
        for service in services {
            guard !service.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ConfigurationError.invalidValue("Every service must have a non-empty name")
            }
            guard ["http", "https"].contains(service.url.scheme?.lowercased() ?? "") else {
                throw ConfigurationError.invalidValue("\(service.name) must use an http or https URL")
            }
            guard identifiers.insert(service.id).inserted else {
                throw ConfigurationError.invalidValue("Duplicate service id: \(service.id)")
            }
            if service.type == .json {
                guard service.jsonPath?.isEmpty == false else {
                    throw ConfigurationError.invalidValue("\(service.name) requires json_path")
                }
                guard service.expectedValue != nil else {
                    throw ConfigurationError.invalidValue("\(service.name) requires expected_value")
                }
            }
        }

        return self
    }
}

enum ServiceType: String, Codable, CaseIterable, Sendable {
    case statuspage
    case http
    case json
}

struct ServiceConfiguration: Codable, Equatable, Hashable, Identifiable, Sendable {
    let configuredID: String?
    let name: String
    let type: ServiceType
    let url: URL
    let expectedStatus: Int?
    let jsonPath: String?
    let expectedValue: String?
    let timeoutSeconds: TimeInterval?

    var id: String {
        if let configuredID, !configuredID.isEmpty {
            return configuredID
        }
        return "\(type.rawValue):\(name):\(url.absoluteString)"
    }

    enum CodingKeys: String, CodingKey {
        case configuredID = "id"
        case name
        case type
        case url
        case statusURL = "status_url"
        case expectedStatus = "expected_status"
        case jsonPath = "json_path"
        case expectedValue = "expected_value"
        case timeoutSeconds = "timeout_seconds"
    }

    init(
        id: String? = nil,
        name: String,
        type: ServiceType = .statuspage,
        url: URL,
        expectedStatus: Int? = nil,
        jsonPath: String? = nil,
        expectedValue: String? = nil,
        timeoutSeconds: TimeInterval? = nil
    ) {
        configuredID = id
        self.name = name
        self.type = type
        self.url = url
        self.expectedStatus = expectedStatus
        self.jsonPath = jsonPath
        self.expectedValue = expectedValue
        self.timeoutSeconds = timeoutSeconds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        configuredID = try container.decodeIfPresent(String.self, forKey: .configuredID)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decodeIfPresent(ServiceType.self, forKey: .type) ?? .statuspage

        let urlString = try container.decodeIfPresent(String.self, forKey: .url)
            ?? container.decode(String.self, forKey: .statusURL)
        guard let parsedURL = URL(string: urlString) else {
            throw DecodingError.dataCorruptedError(
                forKey: .url,
                in: container,
                debugDescription: "Invalid URL: \(urlString)"
            )
        }
        url = parsedURL

        expectedStatus = try container.decodeIfPresent(Int.self, forKey: .expectedStatus)
        jsonPath = try container.decodeIfPresent(String.self, forKey: .jsonPath)
        expectedValue = try container.decodeIfPresent(String.self, forKey: .expectedValue)
        timeoutSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .timeoutSeconds)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(configuredID, forKey: .configuredID)
        try container.encode(name, forKey: .name)
        try container.encode(type, forKey: .type)
        try container.encode(url.absoluteString, forKey: .url)
        try container.encodeIfPresent(expectedStatus, forKey: .expectedStatus)
        try container.encodeIfPresent(jsonPath, forKey: .jsonPath)
        try container.encodeIfPresent(expectedValue, forKey: .expectedValue)
        try container.encodeIfPresent(timeoutSeconds, forKey: .timeoutSeconds)
    }
}

enum ServiceCondition: String, Codable, Equatable, Sendable {
    case operational
    case degraded
    case outage
    case unknown

    var title: String {
        switch self {
        case .operational: "Operational"
        case .degraded: "Degraded"
        case .outage: "Outage"
        case .unknown: "Unknown"
        }
    }

    var color: Color {
        switch self {
        case .operational: .green
        case .degraded: .orange
        case .outage: .red
        case .unknown: .secondary
        }
    }

    var symbolName: String {
        switch self {
        case .operational: "checkmark.circle.fill"
        case .degraded: "exclamationmark.triangle.fill"
        case .outage: "xmark.octagon.fill"
        case .unknown: "questionmark.circle.fill"
        }
    }

    var menuBarSymbolName: String {
        switch self {
        case .operational: "checkmark.circle.fill"
        case .degraded: "exclamationmark.circle.fill"
        case .outage: "xmark.circle.fill"
        case .unknown: "questionmark.circle.fill"
        }
    }
}

struct ServiceStatus: Equatable, Sendable {
    let serviceID: String
    let condition: ServiceCondition
    let message: String
    let checkedAt: Date
    let responseTimeMilliseconds: Int?
}

enum ConfigurationError: LocalizedError, Equatable {
    case unreadableFile(String)
    case invalidJSON(String)
    case invalidValue(String)

    var errorDescription: String? {
        switch self {
        case .unreadableFile(let message): "Could not read configuration: \(message)"
        case .invalidJSON(let message): "Invalid JSON configuration: \(message)"
        case .invalidValue(let message): "Invalid configuration: \(message)"
        }
    }
}
