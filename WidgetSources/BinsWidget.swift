import WidgetKit
import SwiftUI
import Foundation

// MARK: - Timeline Entry

struct BinEntry: TimelineEntry {
    let date: Date
    let binType: String
    let collectionDate: Date
    let isGuess: Bool
    let isConfigured: Bool
}

// MARK: - Timeline Provider

struct BinsTimelineProvider: TimelineProvider {
    private var defaults: UserDefaults {
        UserDefaults(suiteName: "group.MCZH73T4Z2.bins") ?? .standard
    }
    private let endpoint = URL(string: "https://www.centralbedfordshire.gov.uk/info/163/bins_and_waste_collections_-_check_bin_collection_days")!

    func placeholder(in context: Context) -> BinEntry {
        BinEntry(date: Date(), binType: "green", collectionDate: Date(), isGuess: false, isConfigured: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (BinEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BinEntry>) -> Void) {
        guard defaults.string(forKey: "postcode") != nil else {
            let entry = BinEntry(date: Date(), binType: "green", collectionDate: Date(), isGuess: false, isConfigured: false)
            let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(3600)))
            completion(timeline)
            return
        }

        Task {
            let entry = await fetchEntry()
            let refreshDate = Date().addingTimeInterval(6 * 3600)
            let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
            completion(timeline)
        }
    }

    private func currentEntry() -> BinEntry {
        let guess = guessFromReference()
        return BinEntry(
            date: Date(),
            binType: guess.type,
            collectionDate: guess.date,
            isGuess: guess.isGuess,
            isConfigured: defaults.string(forKey: "uprn") != nil
        )
    }

    private func fetchEntry() async -> BinEntry {
        guard let postcode = defaults.string(forKey: "postcode"),
              let uprn = defaults.string(forKey: "uprn"),
              let addressText = defaults.string(forKey: "addressText") else {
            return currentEntry()
        }

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
                defaults.set(next.date, forKey: "refDate")
                defaults.set(next.type, forKey: "refType")
                return BinEntry(
                    date: Date(),
                    binType: next.type,
                    collectionDate: next.date,
                    isGuess: false,
                    isConfigured: true
                )
            }
        } catch {}

        return currentEntry()
    }

    // MARK: - Networking

    private func post(body: String) async throws -> String {
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = body.data(using: .utf8)
        req.timeoutInterval = 15
        let (data, _) = try await URLSession.shared.data(for: req)
        return String(data: data, encoding: .utf8) ?? ""
    }

    private func formEncode(_ params: [String: String]) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return params.map {
            "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: allowed) ?? $0.value)"
        }.joined(separator: "&")
    }

    // MARK: - HTML Parsing

    private func parseCollections(from html: String) -> [(date: Date, type: String)] {
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
                return (date: date, type: "black")
            } else if content.contains("Recycling") {
                return (date: date, type: "green")
            }
            return nil
        }.sorted { $0.date < $1.date }
    }

    // MARK: - Offline Fallback

    private func guessFromReference() -> (date: Date, type: String, isGuess: Bool) {
        guard let refDate = defaults.object(forKey: "refDate") as? Date,
              let refType = defaults.string(forKey: "refType") else {
            return (date: Date(), type: "black", isGuess: true)
        }

        let days = abs(Calendar.current.dateComponents([.day], from: refDate, to: Date()).day ?? 0)
        let weeks = days / 7
        let type = (weeks % 2 == 0) ? refType : (refType == "black" ? "green" : "black")

        let refWeekday = Calendar.current.component(.weekday, from: refDate)
        var next = Calendar.current.startOfDay(for: Date())
        for _ in 0..<7 {
            if Calendar.current.component(.weekday, from: next) == refWeekday { break }
            next = Calendar.current.date(byAdding: .day, value: 1, to: next)!
        }

        return (date: next, type: type, isGuess: true)
    }
}

// MARK: - Widget View

struct BinsWidgetView: View {
    let entry: BinEntry

    var body: some View {
        if !entry.isConfigured {
            VStack(spacing: 8) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                Text("Open Bins app to set up")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .containerBackground(.background, for: .widget)
        } else {
            let isGreen = entry.binType == "green"

            VStack(spacing: 6) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.white)

                Text(isGreen ? "Recycling" : "Refuse")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)

                Text(entry.collectionDate.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.8))

                if entry.isGuess {
                    Text("estimated")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .containerBackground(isGreen ? Color.green : Color.black, for: .widget)
        }
    }
}

// MARK: - Widget Configuration

@main
struct BinsWidget: Widget {
    let kind = "BinsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BinsTimelineProvider()) { entry in
            BinsWidgetView(entry: entry)
        }
        .configurationDisplayName("Bins")
        .description("Shows your next bin collection type.")
        .supportedFamilies([.systemSmall])
    }
}
