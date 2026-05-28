import Foundation
import UserNotifications

enum ReminderScheduler {
    private static let identifierPrefix = "bin-reminder-"
    private static let maxScheduled = 8
    private static let attachmentCacheFolder = "BinNotificationAttachments"

    private static var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "en_GB")
        cal.timeZone = .current
        return cal
    }

    // MARK: - Preferences

    static var remindersEnabled: Bool {
        get {
            if sharedDefaults.object(forKey: "remindersEnabled") == nil { return true }
            return sharedDefaults.bool(forKey: "remindersEnabled")
        }
        set { sharedDefaults.set(newValue, forKey: "remindersEnabled") }
    }

    static var reminderHour: Int {
        get {
            let h = sharedDefaults.integer(forKey: "reminderHour")
            return sharedDefaults.object(forKey: "reminderHour") == nil ? 20 : h
        }
        set { sharedDefaults.set(newValue, forKey: "reminderHour") }
    }

    static var reminderMinute: Int {
        get { sharedDefaults.integer(forKey: "reminderMinute") }
        set { sharedDefaults.set(newValue, forKey: "reminderMinute") }
    }

    // MARK: - Authorization

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    static func isNotificationsDenied() async -> Bool {
        await authorizationStatus() == .denied
    }

    static func requestAuthorizationIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let status = await center.notificationSettings().authorizationStatus
        switch status {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    continuation.resume(returning: granted)
                }
            }
        @unknown default:
            return false
        }
    }

    // MARK: - Scheduling

    static func rescheduleFromStoredAddress() async {
        guard remindersEnabled,
              let postcode = sharedDefaults.string(forKey: "postcode"),
              let uprn = sharedDefaults.string(forKey: "uprn"),
              let addressText = sharedDefaults.string(forKey: "addressText") else {
            await cancelAll()
            return
        }

        guard await requestAuthorizationIfNeeded() else { return }

        let schedule = await BinService.upcomingCollections(
            postcode: postcode,
            uprn: uprn,
            addressText: addressText
        )
        await reschedule(collections: schedule.collections)
    }

    static func reschedule(collections: [BinCollection]) async {
        guard remindersEnabled else {
            await cancelAll()
            return
        }

        guard await requestAuthorizationIfNeeded() else { return }

        await cancelAll()

        let hour = reminderHour
        let minute = reminderMinute
        let now = Date()
        var scheduled = 0

        for collection in collections {
            guard scheduled < maxScheduled,
                  let fireDate = reminderFireDate(for: collection.date, hour: hour, minute: minute),
                  fireDate > now else { continue }

            let content = UNMutableNotificationContent()
            content.title = "Bin reminder"
            content.body = notificationBody(for: collection.type)
            content.sound = .default
            if let attachment = attachment(for: collection.type) {
                content.attachments = [attachment]
            }

            var comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            comps.second = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let id = "\(identifierPrefix)\(collection.date.timeIntervalSince1970)"
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

            try? await UNUserNotificationCenter.current().add(request)
            scheduled += 1
        }
    }

    static func cancelAll() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter { $0.hasPrefix(identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    // MARK: - Helpers

    private static func reminderFireDate(for collectionDate: Date, hour: Int, minute: Int) -> Date? {
        let collectionDay = calendar.startOfDay(for: collectionDate)
        guard let dayBefore = calendar.date(byAdding: .day, value: -1, to: collectionDay) else { return nil }
        var comps = calendar.dateComponents([.year, .month, .day], from: dayBefore)
        comps.hour = hour
        comps.minute = minute
        comps.second = 0
        return calendar.date(from: comps)
    }

    private static func notificationBody(for type: BinType) -> String {
        switch type {
        case .green:
            return "Recycling collection tomorrow"
        case .black:
            return "Refuse (black bin) collection tomorrow"
        }
    }

    /// Colored bin image shown in the notification (green / black). Cached so pending requests stay valid until delivery.
    private static func attachment(for type: BinType) -> UNNotificationAttachment? {
        let resourceName = type == .green ? "GreenBin-152" : "BlackBin-152"
        let cacheFileName = type == .green ? "notification-green.png" : "notification-black.png"

        guard let bundleURL = Bundle.main.url(forResource: resourceName, withExtension: "png") else {
            return nil
        }

        let fileManager = FileManager.default
        guard let cacheRoot = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }

        let cacheDir = cacheRoot.appendingPathComponent(attachmentCacheFolder, isDirectory: true)
        try? fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)

        let fileURL = cacheDir.appendingPathComponent(cacheFileName)
        if !fileManager.fileExists(atPath: fileURL.path) {
            try? fileManager.removeItem(at: fileURL)
            do {
                try fileManager.copyItem(at: bundleURL, to: fileURL)
            } catch {
                return nil
            }
        }

        return try? UNNotificationAttachment(
            identifier: "bin-\(type.rawValue)",
            url: fileURL,
            options: [UNNotificationAttachmentOptionsTypeHintKey: "public.png"]
        )
    }
}
