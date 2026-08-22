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
    private static let basePath = "https://www.centralbedfordshire.gov.uk/waste-and-recycling/waste-collection-schedule"

    // MARK: - Public API

    static func fetchAddresses(postcode: String) async throws -> [Address] {
        let normalized = postcode.replacingOccurrences(of: " ", with: "")
        var components = URLComponents(string: "\(basePath)/find")!
        components.queryItems = [URLQueryItem(name: "postcode", value: normalized)]
        let html = try await get(url: components.url!)
        let addresses = parseAddresses(from: html)
        if addresses.isEmpty {
            throw URLError(.fileDoesNotExist)
        }
        return addresses
    }

    static func upcomingCollections(postcode: String, uprn: String, addressText: String) async -> UpcomingSchedule {
        _ = postcode
        _ = addressText
        do {
            let url = URL(string: "\(basePath)/view/\(uprn)")!
            let html = try await get(url: url)
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

    private static func get(url: URL) async throws -> String {
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 15
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let html = String(data: data, encoding: .utf8) ?? ""
        if html.contains("Page not found") || html.contains("page-not-found") {
            throw URLError(.fileDoesNotExist)
        }
        return html
    }

    // MARK: - HTML Parsing

    private static func parseAddresses(from html: String) -> [Address] {
        let pattern = #"<option value=["'](\d+)["']>([^<]+)</option>"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(html.startIndex..., in: html)
        return regex.matches(in: html, range: range).compactMap { match in
            guard let r1 = Range(match.range(at: 1), in: html),
                  let r2 = Range(match.range(at: 2), in: html) else { return nil }
            return Address(id: String(html[r1]), text: String(html[r2]))
        }
    }

    private static func parseCollections(from html: String) -> [BinCollection] {
        let itemPattern = #"<li class="waste-collection__day">(.*?)</li>"#
        guard let itemRegex = try? NSRegularExpression(pattern: itemPattern, options: .dotMatchesLineSeparators) else {
            return []
        }

        let datePattern = #"datetime="(\d{2}-\d{2}-\d{4})""#
        let typePattern = #"waste-collection__day--type">\s*([^<]+)"#
        guard let dateRegex = try? NSRegularExpression(pattern: datePattern),
              let typeRegex = try? NSRegularExpression(pattern: typePattern, options: .dotMatchesLineSeparators) else {
            return []
        }

        let fmt = DateFormatter()
        fmt.dateFormat = "dd-MM-yyyy"
        fmt.locale = Locale(identifier: "en_GB")

        var grouped: [Date: BinType] = [:]
        let range = NSRange(html.startIndex..., in: html)

        for match in itemRegex.matches(in: html, range: range) {
            guard let itemRange = Range(match.range(at: 1), in: html) else { continue }
            let item = String(html[itemRange])
            let itemNSRange = NSRange(item.startIndex..., in: item)

            guard let dateMatch = dateRegex.firstMatch(in: item, range: itemNSRange),
                  let dateStrRange = Range(dateMatch.range(at: 1), in: item),
                  let typeMatch = typeRegex.firstMatch(in: item, range: itemNSRange),
                  let typeRange = Range(typeMatch.range(at: 1), in: item) else { continue }

            let dateText = String(item[dateStrRange])
            let typeText = String(item[typeRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard let date = fmt.date(from: dateText),
                  let binType = binType(from: typeText) else { continue }

            let day = calendar.startOfDay(for: date)
            if let existing = grouped[day] {
                if existing == .green, binType == .black {
                    grouped[day] = .black
                }
            } else {
                grouped[day] = binType
            }
        }

        return grouped.map { BinCollection(date: $0.key, type: $0.value) }
            .sorted { $0.date < $1.date }
    }

    private static func binType(from label: String) -> BinType? {
        let lower = label.lowercased()
        if lower.contains("refuse") || lower.contains("black bin") {
            return .black
        }
        if lower.contains("recycling") {
            return .green
        }
        return nil
    }

    // MARK: - App Icon

    private static var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "en_GB")
        cal.timeZone = .current
        return cal
    }

    static func isFriday(_ date: Date = Date()) -> Bool {
        calendar.component(.weekday, from: date) == 6
    }

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

    static func refreshAppIconFromStoredAddress() async {
        guard let postcode = sharedDefaults.string(forKey: "postcode"),
              let uprn = sharedDefaults.string(forKey: "uprn"),
              let addressText = sharedDefaults.string(forKey: "addressText") else { return }
        let result = await getCurrentBin(postcode: postcode, uprn: uprn, addressText: addressText)
        await updateIcon(type: result.collection.type)
    }

    @MainActor
    static func updateIcon(type: BinType) {
        guard UIApplication.shared.supportsAlternateIcons else { return }

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

        let days = abs(calendar.dateComponents([.day], from: refDate, to: Date()).day ?? 0)
        let weeks = days / 7
        let type: BinType = (weeks % 2 == 0) ? refType : (refType == .black ? .green : .black)

        let refWeekday = calendar.component(.weekday, from: refDate)
        var next = calendar.startOfDay(for: Date())
        for _ in 0..<7 {
            if calendar.component(.weekday, from: next) == refWeekday {
                break
            }
            next = calendar.date(byAdding: .day, value: 1, to: next)!
        }

        return BinResult(collection: BinCollection(date: next, type: type), isGuess: true)
    }
}
