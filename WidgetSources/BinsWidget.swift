import WidgetKit
import SwiftUI
import Foundation

struct BinEntry: TimelineEntry {
    let date: Date
    let binType: String
    let collectionDate: Date
    let isGuess: Bool
    let isConfigured: Bool
}

struct BinsTimelineProvider: TimelineProvider {
    private var defaults: UserDefaults {
        UserDefaults(suiteName: "group.MCZH73T4Z2.bins") ?? .standard
    }
    private let basePath = "https://www.centralbedfordshire.gov.uk/waste-and-recycling/waste-collection-schedule"

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
        guard let uprn = defaults.string(forKey: "uprn") else {
            return currentEntry()
        }

        do {
            let html = try await get(url: URL(string: "\(basePath)/view/\(uprn)")!)
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

    private func get(url: URL) async throws -> String {
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 15
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return String(data: data, encoding: .utf8) ?? ""
    }

    private func parseCollections(from html: String) -> [(date: Date, type: String)] {
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

        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "en_GB")
        cal.timeZone = .current

        var grouped: [Date: String] = [:]
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

            let day = cal.startOfDay(for: date)
            if let existing = grouped[day] {
                if existing == "green", binType == "black" {
                    grouped[day] = "black"
                }
            } else {
                grouped[day] = binType
            }
        }

        return grouped.map { ($0.key, $0.value) }.sorted { $0.0 < $1.0 }
    }

    private func binType(from label: String) -> String? {
        let lower = label.lowercased()
        if lower.contains("refuse") || lower.contains("black bin") {
            return "black"
        }
        if lower.contains("recycling") {
            return "green"
        }
        return nil
    }

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
