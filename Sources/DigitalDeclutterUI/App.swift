import SwiftUI
import UserNotifications
import DigitalDeclutterCore

@main
struct DeclutterApp: App {
    @Environment(\.openSettings) private var openSettings
    @State private var config = Persistence.loadConfiguration()
    @State private var isRunning = false
    /// Unix timestamp of the last completed run; 0 means never run.
    @AppStorage("lastRunTimestamp") private var lastRunTimestamp: Double = 0

    init() {
        if isAppBundle {
            requestNotificationPermission()
        } else {
            print("⚠️ Running outside a macOS app bundle. System notifications are disabled, but the app will run.")
        }
    }

    var body: some Scene {
        MenuBarExtra {
            // Non-interactive identity label
            Text("DigitalDeclutter")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .disabled(true)

            Divider()

            if isRunning {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 14, height: 14)
                    Text("Organizing files…")
                }
                .disabled(true)
            } else {
                Button("Run Organizer Now") {
                    runOrganizer()
                }
            }

            Button("Preview Changes (Dry Run)") {
                runOrganizer(dryRun: true)
            }
            .disabled(isRunning)

            // Last-run timestamp (shown only after at least one run)
            if lastRunTimestamp > 0 {
                Text("Last run: \(relativeTimeString(from: lastRunTimestamp))")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .disabled(true)
            }

            Divider()

            Button("Preferences…") {
                NSApp.activate(ignoringOtherApps: true)
                openSettings()
            }
            .keyboardShortcut(",", modifiers: .command)

            Divider()

            Button("Quit DigitalDeclutter") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        } label: {
            HStack {
                Image(systemName: isRunning ? "arrow.triangle.2.circlepath.circle.fill" : "folder.badge.gearshape")
                    .symbolEffect(.pulse, options: .repeating, value: isRunning)
            }
        }

        Settings {
            SettingsView(config: $config, onRunNow: { runOrganizer() })
                .frame(
                    minWidth: 560, idealWidth: 600, maxWidth: 800,
                    minHeight: 460, idealHeight: 520, maxHeight: 700
                )
                .navigationTitle("DigitalDeclutter Preferences")
        }
    }

    private var isAppBundle: Bool {
        Bundle.main.bundleIdentifier != nil
    }

    private func runOrganizer(dryRun: Bool = false) {
        isRunning = true
        // Reload configuration before running to capture any manual edits to JSON
        let currentConfig = Persistence.loadConfiguration()
        config = currentConfig

        Task {
            let organizer = FileOrganizer(
                configuration: currentConfig,
                isDryRun: dryRun,
                isLocal: false
            )
            await organizer.run()

            // Record completion timestamp
            lastRunTimestamp = Date().timeIntervalSince1970

            let title = dryRun ? "Dry Run Complete (Simulation)" : "Declutter Complete"
            let subtitle = dryRun
                ? "Simulated moving files. Check terminal or logs."
                : "Your directories have been organized."

            sendNotification(title: title, subtitle: subtitle)
            isRunning = false
        }
    }

    /// Converts a Unix timestamp to a human-readable relative string (e.g. "5m ago").
    private func relativeTimeString(from timestamp: Double) -> String {
        let interval = Date().timeIntervalSince1970 - timestamp
        switch interval {
        case ..<60:        return "just now"
        case ..<3_600:     return "\(Int(interval / 60))m ago"
        case ..<86_400:    return "\(Int(interval / 3_600))h ago"
        default:           return "\(Int(interval / 86_400))d ago"
        }
    }

    private func requestNotificationPermission() {
        guard isAppBundle else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }

    private func sendNotification(title: String, subtitle: String) {
        guard isAppBundle else {
            print("🔔 [Notification Alert] \(title) — \(subtitle)")
            return
        }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = subtitle
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
