import SwiftUI
import UserNotifications
import DigitalDeclutterCore

@main
struct DeclutterApp: App {
    @Environment(\.openSettings) private var openSettings
    @State private var config = Persistence.loadConfiguration()
    @State private var isRunning = false

    init() {
        if isAppBundle {
            requestNotificationPermission()
        } else {
            print("⚠️ Running outside a macOS app bundle. System notifications are disabled, but the app will run.")
        }
    }

    var body: some Scene {
        MenuBarExtra {
            if isRunning {
                Button("Running Organizer...") { }
                    .disabled(true)
            } else {
                Button("Run Organizer Now") {
                    runOrganizer()
                }
            }

            Button("Run as Dry Run") {
                runOrganizer(dryRun: true)
            }
            .disabled(isRunning)

            Divider()

            Button("Preferences...") {
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
            SettingsView(config: $config)
                .frame(width: 550, height: 450)
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

            let title = dryRun ? "Dry Run Complete (Simulation)" : "Declutter Complete"
            let subtitle = dryRun 
                ? "Simulated moving files. Check terminal or logs." 
                : "Your directories have been organized."
            
            sendNotification(title: title, subtitle: subtitle)
            isRunning = false
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
