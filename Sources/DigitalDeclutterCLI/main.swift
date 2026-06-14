import Foundation
import DigitalDeclutterCore

// MARK: - CLI Argument Parsing

/// Parsed options from the command line.
struct ParsedArguments {
    let isDryRun: Bool
    let isLocal: Bool
}

/// Parse command-line flags. Returns `nil` if the user asked for --help.
func parseArguments() -> ParsedArguments? {
    let args = CommandLine.arguments.dropFirst() // drop the executable name

    if args.contains("--help") || args.contains("-h") {
        printUsage()
        return nil
    }

    return ParsedArguments(
        isDryRun: args.contains("--dry-run"),
        isLocal: args.contains("--local")
    )
}

func printUsage() {
    print("""

    \(TermColor.bold)DigitalDeclutterCLI\(TermColor.reset) — Automatically organize cluttered directories.

    \(TermColor.bold)USAGE:\(TermColor.reset)
        DigitalDeclutterCLI              Organize files (moves them for real).
        DigitalDeclutterCLI --dry-run    Preview what would happen, without moving files.
        DigitalDeclutterCLI --local      Organize files locally inside their source directory.
        DigitalDeclutterCLI --help       Show this help message.

    \(TermColor.bold)CONFIGURATION:\(TermColor.reset)
        Loaded from: \(Persistence.configURL.path)

    \(TermColor.bold)SAFETY:\(TermColor.reset)
        • Hidden files (.DS_Store, etc.) are always skipped.
        • Active downloads (.crdownload, .download) are never touched.
        • Name collisions are resolved by appending _1, _2, etc.

    """)
}

// MARK: - Entry Point

guard let parsedArgs = parseArguments() else {
    exit(0) // --help was printed
}

// Load the shared configuration from persistent storage
let configuration = Persistence.loadConfiguration()

let organizer = FileOrganizer(
    configuration: configuration,
    isDryRun: parsedArgs.isDryRun,
    isLocal: parsedArgs.isLocal
)

// Use a semaphore to bridge async → sync at the top level
let semaphore = DispatchSemaphore(value: 0)

Task {
    await organizer.run()
    semaphore.signal()
}

semaphore.wait()
