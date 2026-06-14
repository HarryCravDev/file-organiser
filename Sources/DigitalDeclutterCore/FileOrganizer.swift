import Foundation

/// The core engine that scans directories and moves files according to rules.
public struct FileOrganizer {
    public let configuration: Configuration
    public let isDryRun: Bool
    public let isLocal: Bool
    public let fileManager: FileManager
    public let homeDirectory: URL

    /// Build a fast lookup table: extension → rule.
    private var extensionToRule: [String: OrganizationRule] {
        var map: [String: OrganizationRule] = [:]
        for rule in configuration.rules {
            for ext in rule.extensions {
                map[ext.lowercased()] = rule
            }
        }
        return map
    }

    public init(configuration: Configuration = .default, isDryRun: Bool = false, isLocal: Bool = false) {
        self.configuration = configuration
        self.isDryRun = isDryRun
        self.isLocal = isLocal
        self.fileManager = .default
        self.homeDirectory = fileManager.homeDirectoryForCurrentUser
    }

    // MARK: - Public Entry Point

    /// Run the full organization pass across all configured source directories.
    public func run() async {
        printHeader()

        let lookup = extensionToRule
        var totalMoved = 0
        var totalSkipped = 0
        var totalErrors = 0

        for subpath in configuration.sourceSubpaths {
            let sourceURL = subpath.hasPrefix("/") 
                ? URL(fileURLWithPath: subpath) 
                : homeDirectory.appendingPathComponent(subpath)

            print("\n\(TermColor.cyan)📂 Scanning: \(sourceURL.path)\(TermColor.reset)")
            print("\(TermColor.dim)\(String(repeating: "─", count: 60))\(TermColor.reset)")

            do {
                let files = try enumerateFiles(in: sourceURL)

                if files.isEmpty {
                    print("   \(TermColor.dim)No files found.\(TermColor.reset)")
                    continue
                }

                for fileURL in files {
                    let result = processFile(fileURL, lookup: lookup)
                    switch result {
                    case .moved:
                        totalMoved += 1
                    case .skipped:
                        totalSkipped += 1
                    case .error:
                        totalErrors += 1
                    }
                }
            } catch {
                printError(error.localizedDescription)
                totalErrors += 1
            }
        }

        printSummary(moved: totalMoved, skipped: totalSkipped, errors: totalErrors)
    }

    // MARK: - File Enumeration

    /// Returns the list of non-hidden, non-directory files in the given directory (shallow scan).
    private func enumerateFiles(in directoryURL: URL) throws -> [URL] {
        guard fileManager.fileExists(atPath: directoryURL.path) else {
            throw OrganizerError.directoryNotFound(directoryURL.path)
        }

        let contents: [URL]
        do {
            contents = try fileManager.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: [.isRegularFileKey, .isHiddenKey],
                options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
            )
        } catch {
            throw OrganizerError.scanFailed(directoryURL.path, underlying: error)
        }

        // Filter to regular files only (skip directories, symlinks to dirs, etc.)
        return contents.filter { url in
            let values = try? url.resourceValues(forKeys: [.isRegularFileKey])
            return values?.isRegularFile == true
        }
    }

    // MARK: - File Processing

    enum ProcessResult {
        case moved, skipped, error
    }

    /// Evaluate a single file against the rules and either move it or log the action.
    private func processFile(_ fileURL: URL, lookup: [String: OrganizationRule]) -> ProcessResult {
        let filename = fileURL.lastPathComponent
        let ext = fileURL.pathExtension.lowercased()

        // Guard: skip hidden files that somehow bypassed the enumerator filter.
        if filename.hasPrefix(".") {
            printSkipped(filename, reason: "hidden file")
            return .skipped
        }

        // Guard: skip ignored extensions (active downloads, temp files).
        if configuration.ignoredExtensions.contains(ext) {
            printSkipped(filename, reason: "ignored extension (.\(ext))")
            return .skipped
        }

        // Guard: skip files with no matching rule.
        guard let rule = lookup[ext] else {
            printSkipped(filename, reason: "no matching rule for .\(ext)")
            return .skipped
        }

        let destinationDir: URL
        if isLocal {
            let sourceDir = fileURL.deletingLastPathComponent()
            destinationDir = sourceDir.appendingPathComponent(rule.category)
        } else {
            let subpath = rule.destinationSubpath
            destinationDir = subpath.hasPrefix("/")
                ? URL(fileURLWithPath: subpath)
                : homeDirectory.appendingPathComponent(subpath)
        }
        let proposedDestination = destinationDir.appendingPathComponent(filename)
        let safeDestination = resolveNameCollision(for: proposedDestination)

        if isDryRun {
            printDryRun(filename, category: rule.category, destination: safeDestination)
            return .moved // count it for the summary
        }

        // Real move: ensure destination directory exists, then move.
        do {
            try ensureDirectoryExists(at: destinationDir)
            try fileManager.moveItem(at: fileURL, to: safeDestination)
            printMoved(filename, category: rule.category, destination: safeDestination)
            return .moved
        } catch {
            printError("Could not move '\(filename)': \(error.localizedDescription)")
            return .error
        }
    }

    // MARK: - Name Collision Resolution

    /// If a file already exists at the proposed URL, append an incrementing counter
    /// (e.g. `report_1.pdf`, `report_2.pdf`) until a free slot is found.
    private func resolveNameCollision(for url: URL) -> URL {
        guard fileManager.fileExists(atPath: url.path) else {
            return url // no collision
        }

        let directory = url.deletingLastPathComponent()
        let stem = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        var counter = 1

        while true {
            let candidateName = ext.isEmpty
                ? "\(stem)_\(counter)"
                : "\(stem)_\(counter).\(ext)"
            let candidate = directory.appendingPathComponent(candidateName)

            if !fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
            counter += 1
        }
    }

    // MARK: - Directory Helpers

    /// Create the directory (and intermediates) if it doesn't already exist.
    private func ensureDirectoryExists(at url: URL) throws {
        var isDir: ObjCBool = false
        if fileManager.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
            return // already exists
        }
        do {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        } catch {
            throw OrganizerError.directoryCreationFailed(url.path, underlying: error)
        }
    }

    // MARK: - Logging

    private func printHeader() {
        print()
        print("\(TermColor.bold)\(TermColor.cyan)╔══════════════════════════════════════════════════════════╗\(TermColor.reset)")
        print("\(TermColor.bold)\(TermColor.cyan)║           🗂  DigitalDeclutter  File Organizer           ║\(TermColor.reset)")
        print("\(TermColor.bold)\(TermColor.cyan)╚══════════════════════════════════════════════════════════╝\(TermColor.reset)")

        if isLocal {
            print("\(TermColor.cyan)📍 LOCAL MODE — files will be organized inside their source directories.\(TermColor.reset)")
        }
        if isDryRun {
            print("\(TermColor.yellow)⚠  DRY-RUN MODE — no files will be moved.\(TermColor.reset)")
        }
    }

    private func printMoved(_ filename: String, category: String, destination: URL) {
        let short = abbreviateHome(destination.path)
        print("   \(TermColor.green)✔ [\(category)]\(TermColor.reset) \(filename) → \(TermColor.dim)\(short)\(TermColor.reset)")
    }

    private func printDryRun(_ filename: String, category: String, destination: URL) {
        let short = abbreviateHome(destination.path)
        print("   \(TermColor.yellow)⏩ [DRY-RUN · \(category)]\(TermColor.reset) \(filename) → \(TermColor.dim)\(short)\(TermColor.reset)")
    }

    private func printSkipped(_ filename: String, reason: String) {
        print("   \(TermColor.dim)⊘  Skipped: \(filename) (\(reason))\(TermColor.reset)")
    }

    private func printError(_ message: String) {
        print("   \(TermColor.red)✖  Error: \(message)\(TermColor.reset)")
    }

    private func printSummary(moved: Int, skipped: Int, errors: Int) {
        print()
        print("\(TermColor.dim)\(String(repeating: "═", count: 60))\(TermColor.reset)")
        let action = isDryRun ? "Would move" : "Moved"
        print("\(TermColor.bold)  \(action): \(moved)  │  Skipped: \(skipped)  │  Errors: \(errors)\(TermColor.reset)")
        print("\(TermColor.dim)\(String(repeating: "═", count: 60))\(TermColor.reset)")
        print()
    }

    /// Replace the home directory prefix with ~ for cleaner output.
    private func abbreviateHome(_ path: String) -> String {
        let home = homeDirectory.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }
}
