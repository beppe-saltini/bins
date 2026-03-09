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
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.taskId, using: nil) { task in
            Self.handleRefresh(task: task as! BGAppRefreshTask)
        }
        Self.scheduleRefresh()
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
    }

    static func scheduleRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: taskId)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 24 * 3600)
        try? BGTaskScheduler.shared.submit(request)
    }

    static func handleRefresh(task: BGAppRefreshTask) {
        scheduleRefresh()

        let operation = Task {
            guard let postcode = sharedDefaults.string(forKey: "postcode"),
                  let uprn = sharedDefaults.string(forKey: "uprn"),
                  let addressText = sharedDefaults.string(forKey: "addressText") else {
                return
            }

            let result = await BinService.getCurrentBin(postcode: postcode, uprn: uprn, addressText: addressText)

            DispatchQueue.main.async {
                BinService.updateIcon(type: result.collection.type)
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
