import WidgetKit
import SwiftUI

struct GlucoseEntry: TimelineEntry {
    let date: Date
    let glucose: String
    let trend: String
    let age: String
    let isStale: Bool
    let dateString: String
    static var placeholder: GlucoseEntry {
        GlucoseEntry(date: Date(), glucose: "120", trend: "→", age: "1m", isStale: false, dateString: "Apr 3")
    }
}

struct GlucoseTimelineProvider: TimelineProvider {
    let stalenessInterval: TimeInterval = 15 * 60

    func placeholder(in context: Context) -> GlucoseEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (GlucoseEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
            return
        }
        completion(readGlucose())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GlucoseEntry>) -> Void) {
        let entry = readGlucose()
        var entries: [GlucoseEntry] = [entry]

        if !entry.isStale {
            let df = DateFormatter(); df.dateFormat = "MMM d"
            let staleDate = Date().addingTimeInterval(stalenessInterval)
            entries.append(GlucoseEntry(
                date: staleDate, glucose: "---", trend: "", age: "",
                isStale: true, dateString: df.string(from: staleDate)
            ))
        }

        completion(Timeline(entries: entries, policy: .after(Date().addingTimeInterval(5 * 60))))
    }

    /// Reads glucose from the shared App Group UserDefaults.
    /// The WatchApp Extension writes here whenever it receives
    /// new glucose data from the phone via WatchConnectivity.
    private func readGlucose() -> GlucoseEntry {
        let df = DateFormatter(); df.dateFormat = "MMM d"
        let dateStr = df.string(from: Date())
        let staleEntry = GlucoseEntry(
            date: Date(), glucose: "---", trend: "", age: "", isStale: true, dateString: dateStr
        )

        // Read the App Group identifier from Info.plist
        guard let groupID = Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String,
              !groupID.isEmpty,
              let defaults = UserDefaults(suiteName: groupID) else {
            return staleEntry
        }

        let glucoseValue = defaults.double(forKey: "widget_glucose_value")
        guard glucoseValue > 0,
              let glucoseDate = defaults.object(forKey: "widget_glucose_date") as? Date else {
            return staleEntry
        }

        let trendSymbol = defaults.string(forKey: "widget_glucose_trend") ?? ""
        let unitStr = defaults.string(forKey: "widget_glucose_unit") ?? "mg/dL"

        let glucoseStr: String
        if unitStr == "mmol/L" {
            glucoseStr = String(format: "%.1f", glucoseValue)
        } else {
            glucoseStr = String(format: "%.0f", glucoseValue)
        }

        let sec = Date().timeIntervalSince(glucoseDate)
        let stale = sec > stalenessInterval
        let min = Int(sec / 60)
        let age: String
        if min < 1 { age = "now" }
        else if min < 60 { age = "\(min)m" }
        else { age = "\(min/60)h\(min%60)m" }

        return GlucoseEntry(
            date: Date(), glucose: stale ? "---" : glucoseStr,
            trend: stale ? "" : trendSymbol, age: age,
            isStale: stale, dateString: dateStr
        )
    }
}

struct CircularView: View {
    let entry: GlucoseEntry
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Text(entry.glucose + entry.trend)
                    .font(.system(size: entry.glucose.count > 3 ? 13 : 15, weight: .bold, design: .rounded))
                    .foregroundColor(entry.isStale ? .gray : .white)
                    .minimumScaleFactor(0.7)
                if !entry.age.isEmpty {
                    Text(entry.age)
                        .font(.system(size: 9, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

struct CornerView: View {
    let entry: GlucoseEntry
    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text(entry.glucose + entry.trend)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(entry.isStale ? .gray : .white)
            Text("\(entry.dateString) | \(entry.age)")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
    }
}

struct RectangularView: View {
    let entry: GlucoseEntry
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.glucose + entry.trend)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(entry.isStale ? .gray : .white)
                HStack(spacing: 4) {
                    Text(entry.dateString)
                    Text("|")
                    Text(entry.age).foregroundColor(entry.isStale ? .red : .secondary)
                }
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            }
            Spacer()
        }
    }
}

struct InlineView: View {
    let entry: GlucoseEntry
    var body: some View {
        Text("\(entry.glucose)\(entry.trend) | \(entry.dateString) | \(entry.age)")
    }
}

@main
struct GlucoseWidget: Widget {
    let kind = "GlucoseWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GlucoseTimelineProvider()) { entry in
            GlucoseWidgetView(entry: entry)
        }
        .configurationDisplayName("Glucose")
        .description("Live glucose from Loop")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryRectangular, .accessoryInline])
    }
}

struct GlucoseWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: GlucoseEntry
    var body: some View {
        switch family {
        case .accessoryCircular: CircularView(entry: entry)
        case .accessoryCorner: CornerView(entry: entry)
        case .accessoryRectangular: RectangularView(entry: entry)
        case .accessoryInline: InlineView(entry: entry)
        @unknown default: CircularView(entry: entry)
        }
    }
}
