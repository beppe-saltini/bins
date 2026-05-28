import SwiftUI
import BackgroundTasks
import WidgetKit

@main
struct BinsApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    private static let taskId = "com.beppe.BinsApp.refresh"

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        Self.migrateToSharedDefaults()
        if sharedDefaults.string(forKey: "uprn") != nil {
            Task { await BinService.refreshAppIconFromStoredAddress() }
        }
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.taskId, using: nil) { task in
            Self.handleRefresh(task: task as! BGAppRefreshTask)
        }
        Self.scheduleFridayRefresh()
        return true
    }

    static func migrateToSharedDefaults() {
        let old = UserDefaults.standard
        guard sharedDefaults.string(forKey: "uprn") == nil,
              let uprn = old.string(forKey: "uprn") else { return }

        for key in ["postcode", "uprn", "addressText", "refType"] {
            if let val = old.string(forKey: key) {
                sharedDefaults.set(val, forKey: key)
            }
        }
        if let date = old.object(forKey: "refDate") as? Date {
            sharedDefaults.set(date, forKey: "refDate")
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Background refresh is scheduled for Friday morning only (best-effort).
    /// Opening the app any day still updates the icon in `ContentView.refresh()`.
    static func scheduleFridayRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: taskId)
        request.earliestBeginDate = BinService.nextFridayMorning()
        try? BGTaskScheduler.shared.submit(request)
    }

    static func handleRefresh(task: BGAppRefreshTask) {
        scheduleFridayRefresh()

        let operation = Task {
            await BinService.refreshAppIconFromStoredAddress()
            await ReminderScheduler.rescheduleFromStoredAddress()
            await MainActor.run {
                WidgetCenter.shared.reloadAllTimelines()
            }
        }

        task.expirationHandler = {
            operation.cancel()
        }

        Task {
            _ = await operation.result
            task.setTaskCompleted(success: true)
        }
    }
}
