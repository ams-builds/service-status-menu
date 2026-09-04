import Foundation
import Yams

struct ConfigurationLoader {
    static let environmentVariable = "SERVICE_STATUS_CONFIG"

    static let starterConfiguration = """
    # Service Status menu bar configuration
    # Changes can be loaded from the app without restarting it.

    poll_interval_seconds: 300
    request_timeout_seconds: 10

    services:
      - name: GitHub
        type: statuspage
        url: https://www.githubstatus.com

      - name: OpenAI
        type: statuspage
        url: https://status.openai.com

      - name: Anthropic
        type: statuspage
        url: https://status.anthropic.com

      - name: Cloudflare
        type: statuspage
        url: https://www.cloudflarestatus.com

      - name: Supabase
        type: statuspage
        url: https://status.supabase.com

      # A website you control can be checked by HTTP status:
      # - name: My website
      #   type: http
      #   url: https://example.com
      #   expected_status: 200

      # A JSON health endpoint can be checked by a dotted path:
      # - name: My API
      #   type: json
      #   url: https://api.example.com/health
      #   json_path: status
      #   expected_value: healthy
    """

    let fileManager: FileManager
    let environment: [String: String]

    init(
        fileManager: FileManager = .default,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.fileManager = fileManager
        self.environment = environment
    }

    func defaultConfigurationURL() throws -> URL {
        if let override = environment[Self.environmentVariable], !override.isEmpty {
            return URL(fileURLWithPath: NSString(string: override).expandingTildeInPath)
        }

        guard let applicationSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw ConfigurationError.unreadableFile("Application Support directory is unavailable")
        }

        return applicationSupport
            .appendingPathComponent("Service Status", isDirectory: true)
            .appendingPathComponent("services.yaml", isDirectory: false)
    }

    @discardableResult
    func createStarterConfigurationIfNeeded(at url: URL) throws -> Bool {
        guard !fileManager.fileExists(atPath: url.path) else {
            return false
        }

        do {
            try fileManager.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try Self.starterConfiguration.write(to: url, atomically: true, encoding: .utf8)
            return true
        } catch {
            throw ConfigurationError.unreadableFile(error.localizedDescription)
        }
    }

    func load(from url: URL) throws -> AppConfiguration {
        let yaml: String
        do {
            yaml = try String(contentsOf: url, encoding: .utf8)
        } catch {
            throw ConfigurationError.unreadableFile(error.localizedDescription)
        }

        do {
            return try YAMLDecoder().decode(AppConfiguration.self, from: yaml).validated()
        } catch let error as ConfigurationError {
            throw error
        } catch {
            throw ConfigurationError.invalidYAML(error.localizedDescription)
        }
    }
}
