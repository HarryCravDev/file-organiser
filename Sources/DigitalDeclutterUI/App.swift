import SwiftUI
import UserNotifications
import DigitalDeclutterCore

@main
struct DeclutterApp: App {
    @Environment(\.openSettings) private var openSettings
    @State private var config = Persistence.loadConfiguration()
    @StateObject private var automationManager = AutomationManager.shared
    /// Unix timestamp of the last completed run; 0 means never run.
    @AppStorage("lastRunTimestamp") private var lastRunTimestamp: Double = 0

    init() {
        let loadedConfig = Persistence.loadConfiguration()
        AutomationManager.shared.setup(config: loadedConfig)

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

            // Display active automation status
            if config.isAutomationEnabled {
                let statusText = config.automationType == .realTime ? "Auto-Declutter: Real-Time" : "Auto-Declutter: Scheduled"
                Text(statusText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .disabled(true)
            } else {
                Text("Auto-Declutter: Off")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .disabled(true)
            }

            Divider()

            if automationManager.isRunning {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 14, height: 14)
                    Text("Organizing files…")
                }
                .disabled(true)
            } else {
                Button("Run Organizer Now") {
                    automationManager.runOrganizer()
                }
            }

            Button("Preview Changes (Dry Run)") {
                automationManager.runOrganizer(dryRun: true)
            }
            .disabled(automationManager.isRunning)

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
                Image(systemName: automationManager.isRunning ? "arrow.triangle.2.circlepath.circle.fill" : "folder.badge.gearshape")
                    .symbolEffect(.pulse, options: .repeating, value: automationManager.isRunning)
            }
        }

        Settings {
            SettingsView(config: $config, onRunNow: { automationManager.runOrganizer() })
                .frame(
                    minWidth: 640, idealWidth: 680, maxWidth: 880,
                    minHeight: 460, idealHeight: 520, maxHeight: 700
                )
                .navigationTitle("DigitalDeclutter Preferences")
                .onChange(of: config) { oldValue, newValue in
                    automationManager.setup(config: newValue)
                }
        }
    }

    private var isAppBundle: Bool {
        Bundle.main.bundleIdentifier != nil
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
}
