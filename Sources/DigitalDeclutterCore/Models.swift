import Foundation

// MARK: - ANSI Colors for Terminal Output

/// Lightweight namespace for terminal color codes.
public enum TermColor {
    public static let reset   = "\u{001B}[0m"
    public static let bold    = "\u{001B}[1m"
    public static let red     = "\u{001B}[31m"
    public static let green   = "\u{001B}[32m"
    public static let yellow  = "\u{001B}[33m"
    public static let cyan    = "\u{001B}[36m"
    public static let dim     = "\u{001B}[2m"
}

// MARK: - Configuration Model

/// A rule that maps a set of file extensions to a destination directory.
public struct OrganizationRule: Codable, Hashable, Equatable {
    /// Human-readable category name (e.g. "Images").
    public var category: String
    /// Lowercase file extensions this rule matches (without leading dot).
    public var extensions: Set<String>
    /// Destination directory path, relative to the user's home directory.
    public var destinationSubpath: String

    public init(category: String, extensions: Set<String>, destinationSubpath: String) {
        self.category = category
        self.extensions = extensions
        self.destinationSubpath = destinationSubpath
    }
}

/// Top-level configuration for the organizer.
public struct Configuration: Codable, Equatable {
    /// Rules that determine where each file type goes.
    public var rules: [OrganizationRule]
    /// File extensions that should always be skipped (active downloads, temp files).
    public var ignoredExtensions: Set<String>
    /// Directories to scan, relative to the user's home directory.
    public var sourceSubpaths: [String]

    public init(rules: [OrganizationRule], ignoredExtensions: Set<String>, sourceSubpaths: [String]) {
        self.rules = rules
        self.ignoredExtensions = ignoredExtensions
        self.sourceSubpaths = sourceSubpaths
    }

    /// The default built-in configuration.
    public static let `default` = Configuration(
        rules: [
            OrganizationRule(
                category: "Images",
                extensions: ["png", "jpg", "jpeg"],
                destinationSubpath: "Pictures/Screenshots"
            ),
            OrganizationRule(
                category: "Documents",
                extensions: ["pdf", "docx", "pages"],
                destinationSubpath: "Documents/Organized"
            ),
            OrganizationRule(
                category: "Installers",
                extensions: ["dmg", "pkg"],
                destinationSubpath: "Downloads/Installers"
            ),
        ],
        ignoredExtensions: ["crdownload", "download", "part", "tmp"],
        sourceSubpaths: ["Desktop", "Downloads"]
    )
}

// MARK: - Organizer Errors

/// Errors specific to the file organization process.
public enum OrganizerError: LocalizedError {
    case directoryNotFound(String)
    case scanFailed(String, underlying: Error)
    case moveFailed(source: String, destination: String, underlying: Error)
    case directoryCreationFailed(String, underlying: Error)

    public var errorDescription: String? {
        switch self {
        case .directoryNotFound(let path):
            return "Directory not found: \(path)"
        case .scanFailed(let path, let underlying):
            return "Failed to scan '\(path)': \(underlying.localizedDescription)"
        case .moveFailed(let source, let destination, let underlying):
            return "Failed to move '\(source)' → '\(destination)': \(underlying.localizedDescription)"
        case .directoryCreationFailed(let path, let underlying):
            return "Failed to create directory '\(path)': \(underlying.localizedDescription)"
        }
    }
}
