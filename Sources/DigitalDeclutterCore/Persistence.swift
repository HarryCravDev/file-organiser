import Foundation

/// Handles loading and saving the application configuration as a JSON file.
public struct Persistence {
    private static let fileManager = FileManager.default

    /// Path to config.json: ~/Library/Application Support/DigitalDeclutter/config.json
    public static var configURL: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("DigitalDeclutter")
        return appDir.appendingPathComponent("config.json")
    }

    /// Load the configuration from the persisted JSON. If it doesn't exist, create a default one.
    public static func loadConfiguration() -> Configuration {
        let url = configURL

        if fileManager.fileExists(atPath: url.path) {
            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                let config = try decoder.decode(Configuration.self, from: data)
                return config
            } catch {
                print("\(TermColor.yellow)⚠ Warning: Failed to parse configuration from \(url.path): \(error.localizedDescription). Using defaults.\(TermColor.reset)")
            }
        }

        // Configuration doesn't exist or failed to load. Create and persist the default configuration.
        let defaultConfig = Configuration.default
        saveConfiguration(defaultConfig)
        return defaultConfig
    }

    /// Save the configuration to the JSON file.
    public static func saveConfiguration(_ config: Configuration) {
        let url = configURL
        let directory = url.deletingLastPathComponent()

        do {
            if !fileManager.fileExists(atPath: directory.path) {
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            }

            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(config)
            try data.write(to: url, options: .atomic)
        } catch {
            print("\(TermColor.red)✖ Error: Failed to save configuration to \(url.path): \(error.localizedDescription)\(TermColor.reset)")
        }
    }
}
