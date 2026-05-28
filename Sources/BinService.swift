import Foundation
import UIKit

enum BinType: String {
    case black
    case green
}

struct BinCollection {
    let date: Date
    let type: BinType
}

struct BinResult {
    let collection: BinCollection
    let isGuess: Bool
}

struct UpcomingSchedule {
    let collections: [BinCollection]
    let isGuess: Bool
}

struct Address: Identifiable, Hashable {
    let id: String
    let text: String
}

let sharedDefaults = UserDefaults(suiteName: "group.MCZH73T4Z2.bins") ?? .standard

enum BinService {
    private static let endpoint = URL(string: "https://www.centralbedfordshire.gov.uk/info/163/bins_and_waste_collections_-_check_bin_collection_days")!

    // MARK: - Public API

    static func fetchAddresses(postcode: String) async throws -> [Address] {
        let body = formEncode(["postcode": postcode, "search": "Search"])
        let html = try await post(body: body)
        return parseAddresses(from: html)
    }

    static func upcomingCollections(postcode: String, uprn: String, addressText: String) async -> UpcomingSchedule {
        do {
            let body = formEncode([
                "postcode": postcode,
                "address": uprn,
                "address_text": addressText,
                "search": "View"
            ])
            let html = try await post(body: body)
            let collections = parseCollections(from: html)
            let today = calendar.startOfDay(for: Date())
            let upcoming = collections.filter { $0.date >= today }

            if let first = upcoming.first {
                saveReference(date: first.date, type: first.type)
                return UpcomingSchedule(collections: upcoming, isGuess: false)
            }
        } catch {
            // Network unavailable — fall through to offline guess
        }

        let guess = guessFromReference()
        return UpcomingSchedule(collections: [guess.collection], isGuess: true)
    }

    static func getCurrentBin(postcode: String, uprn: String, addressText: String) async -> BinResult {
        let schedule = await upcomingCollections(postcode: postcode, uprn: uprn, addressText: addressText)
        guard let first = schedule.collections.first else { return guessFromReference() }
        return BinResult(collection: first, isGuess: schedule.isGuess)
    }

    // MARK: - Networking

    private static func post(body: String) async throws -> String {
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = body.data(using: .utf8)
        req.timeoutInterval = 15
        let (data, _) = try await URLSession.shared.data(for: req)
        return String(data: data, encoding: .utf8) ?? ""
    }

    private static func formEncode(_ params: [String: String]) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return params.map {
            "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: allowed) ?? $0.value)"
        }.joined(separator: "&")
    }

    // MARK: - HTML Parsing

    private static func parseAddresses(from html: String) -> [Address] {
        let pattern = #"<option value='(\d+)'>([^<]+)</option>"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(html.startIndex..., in: html)
        return regex.matches(in: html, range: range).compactMap { match in
            guard let r1 = Range(match.range(at: 1), in: html),
                  let r2 = Range(match.range(at: 2), in: html) else { return nil }
            return Address(id: String(html[r1]), text: String(html[r2]))
        }
    }

    private static func parseCollections(from html: String) -> [BinCollection] {
        let pattern = #"<h3>([^<]+)</h3>(.*?)(?=<h3|$)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators) else { return [] }

        let fmt = DateFormatter()
        fmt.dateFormat = "EEEE, d MMMM yyyy"
        fmt.locale = Locale(identifier: "en_GB")

        let range = NSRange(html.startIndex..., in: html)
        return regex.matches(in: html, range: range).compactMap { match in
            guard let r1 = Range(match.range(at: 1), in: html),
                  let r2 = Range(match.range(at: 2), in: html) else { return nil }
            let dateStr = String(html[r1]).trimmingCharacters(in: .whitespaces)
            guard let date = fmt.date(from: dateStr) else { return nil }
            let content = String(html[r2])
            if content.contains("Refuse (black bin)") {
                return BinCollection(date: date, type: .black)
            } else if content.contains("Recycling") {
                return BinCollection(date: date, type: .green)
            }
            return nil
        }.sorted { $0.date < $1.date }
    }

    // MARK: - App Icon (alternate icon on the home screen app grid)

    private static var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "en_GB")
        cal.timeZone = .current
        return cal
    }

    /// Friday = weekday 6 in `Calendar` (Sunday is 1).
    static func isFriday(_ date: Date = Date()) -> Bool {
        calendar.component(.weekday, from: date) == 6
    }

    /// Next Friday at 07:00 local time, for scheduling background refresh.
    static func nextFridayMorning(from date: Date = Date()) -> Date {
        let startOfToday = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: date)
        let daysUntilFriday = (6 - weekday + 7) % 7
        guard var friday = calendar.date(byAdding: .day, value: daysUntilFriday, to: startOfToday) else {
            return date.addingTimeInterval(3600)
        }
        var comps = calendar.dateComponents([.year, .month, .day], from: friday)
        comps.hour = 7
        comps.minute = 0
        guard var result = calendar.date(from: comps) else { return date.addingTimeInterval(3600) }
        if result <= date {
            guard let nextWeek = calendar.date(byAdding: .day, value: 7, to: friday) else { return result }
            comps = calendar.dateComponents([.year, .month, .day], from: nextWeek)
            comps.hour = 7
            comps.minute = 0
            result = calendar.date(from: comps) ?? result
        }
        return result
    }

    /// Fetches the next collection and updates the alternate app icon (green / black).
    static func refreshAppIconFromStoredAddress() async {
        guard let postcode = sharedDefaults.string(forKey: "postcode"),
              let uprn = sharedDefaults.string(forKey: "uprn"),
              let addressText = sharedDefaults.string(forKey: "addressText") else { return }
        let result = await getCurrentBin(postcode: postcode, uprn: uprn, addressText: addressText)
        await MainActor.run {
            updateIcon(type: result.collection.type)
        }
    }

    static func updateIcon(type: BinType) {
        guard UIApplication.shared.supportsAlternateIcons else { return }

        // Primary icon is green; only switch to alternate for refuse week.
        let desired: String? = (type == .black) ? "BlackBin" : nil
        guard UIApplication.shared.alternateIconName != desired else { return }

        UIApplication.shared.setAlternateIconName(desired) { error in
            if let error {
                NSLog("Bins: failed to set app icon: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Offline Fallback

    private static func saveReference(date: Date, type: BinType) {
        sharedDefaults.set(date, forKey: "refDate")
        sharedDefaults.set(type.rawValue, forKey: "refType")
    }

    static func guessFromReference() -> BinResult {
        guard let refDate = sharedDefaults.object(forKey: "refDate") as? Date,
              let raw = sharedDefaults.string(forKey: "refType"),
              let refType = BinType(rawValue: raw) else {
            return BinResult(collection: BinCollection(date: Date(), type: .black), isGuess: true)
        }

        let days = abs(Calendar.current.dateComponents([.day], from: refDate, to: Date()).day ?? 0)
        let weeks = days / 7
        let type: BinType = (weeks % 2 == 0) ? refType : (refType == .black ? .green : .black)

        let refWeekday = Calendar.current.component(.weekday, from: refDate)
        var next = Calendar.current.startOfDay(for: Date())
        for _ in 0..<7 {
            if Calendar.current.component(.weekday, from: next) == refWeekday {
                break
            }
            next = Calendar.current.date(byAdding: .day, value: 1, to: next)!
        }

        return BinResult(collection: BinCollection(date: next, type: type), isGuess: true)
    }
}
