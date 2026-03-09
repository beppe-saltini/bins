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

struct Address: Identifiable, Hashable {
    let id: String
    let text: String
}

let sharedDefaults = UserDefaults(suiteName: "group.com.beppe.BinsApp")!

enum BinService {
    private static let endpoint = URL(string: "https://www.centralbedfordshire.gov.uk/info/2/waste_and_recycling/601/bins_and_waste_collections")!

    // MARK: - Public API

    static func fetchAddresses(postcode: String) async throws -> [Address] {
        let body = formEncode(["postcode": postcode, "search": "Search"])
        let html = try await post(body: body)
        return parseAddresses(from: html)
    }

    static func getCurrentBin(postcode: String, uprn: String, addressText: String) async -> BinResult {
        do {
            let body = formEncode([
                "postcode": postcode,
                "address": uprn,
                "address_text": addressText,
                "search": "View"
            ])
            let html = try await post(body: body)
            let collections = parseCollections(from: html)
            let today = Calendar.current.startOfDay(for: Date())

            if let next = collections.first(where: { $0.date >= today }) {
                saveReference(date: next.date, type: next.type)
                return BinResult(collection: next, isGuess: false)
            }
        } catch {
            // Network unavailable — fall through to offline guess
        }

        return guessFromReference()
    }

    // MARK: - Networking

    private static func post(body: String) async throws -> String {
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = body.data(using: .utf8)
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

    // MARK: - App Icon

    static func updateIcon(type: BinType) {
        let desired: String? = (type == .black) ? "BlackBin" : nil
        guard UIApplication.shared.alternateIconName != desired else { return }

        let selector = NSSelectorFromString("_setAlternateIconName:completionHandler:")
        guard UIApplication.shared.responds(to: selector) else { return }

        typealias SetIconFn = @convention(c) (AnyObject, Selector, AnyObject?, AnyObject?) -> Void
        let imp = UIApplication.shared.method(for: selector)
        let fn = unsafeBitCast(imp, to: SetIconFn.self)
        fn(UIApplication.shared, selector, desired as NSString?, nil)
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
