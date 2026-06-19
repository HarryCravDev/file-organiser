import Foundation
import UserNotifications
import DigitalDeclutterCore

@MainActor
public final class AutomationManager: ObservableObject {
    public static let shared = AutomationManager()
    
    @Published public var isRunning = false
    
    private var watcher: FolderWatcher?
    private var scheduleTask: Task<Void, Never>?
    private var config: Configuration = .default
    
    private init() {}
    
    public func setup(config: Configuration) {
        self.config = config
        restart()
    }
    
    public func restart() {
        // stop existing watcher
        watcher = nil
        
        // stop existing timer
        scheduleTask?.cancel()
        scheduleTask = nil
        
        guard config.isAutomationEnabled else { return }
        
        switch config.automationType {
        case .realTime:
            watcher = FolderWatcher(paths: config.sourceSubpaths) { [weak self] in
                Task { @MainActor in
                    self?.runOrganizer(dryRun: false)
                }
            }
        case .scheduled:
            let minutes = config.scheduleIntervalMinutes
            guard minutes > 0 else { return }
            scheduleTask = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(Double(minutes) * 60.0))
                    if Task.isCancelled { break }
                    await MainActor.run {
                        self?.runOrganizer(dryRun: false)
                    }
                }
            }
        }
    }
    
    public func runOrganizer(dryRun: Bool = false) {
        guard !isRunning else { return }
        isRunning = true
        
        // Reload configuration before running to capture any manual edits to JSON
        let currentConfig = Persistence.loadConfiguration()
        self.config = currentConfig
        
        Task {
            let organizer = FileOrganizer(
                configuration: currentConfig,
                isDryRun: dryRun,
                isLocal: false
            )
            await organizer.run()
            
            // Record completion timestamp
            let timestamp = Date().timeIntervalSince1970
            UserDefaults.standard.set(timestamp, forKey: "lastRunTimestamp")
            
            let title = dryRun ? "Dry Run Complete (Simulation)" : "Declutter Complete"
            let subtitle = dryRun
                ? "Simulated moving files. Check terminal or logs."
                : "Your directories have been organized."
            
            sendNotification(title: title, subtitle: subtitle)
            isRunning = false
        }
    }
    
    private func sendNotification(title: String, subtitle: String) {
        let isAppBundle = Bundle.main.bundleIdentifier != nil
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
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Notification posting error: \(error)")
            }
        }
    }
}
