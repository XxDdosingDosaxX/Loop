import WidgetKit
import SwiftUI

struct GlucoseEntry: TimelineEntry {
    let date: Date
    let glucose: String
    let trend: String
    let age: String
    let isStale: Bool
    let dateString: String
    let loopColor: Color

    static var placeholder: GlucoseEntry {
        GlucoseEntry(date: Date(), glucose: "120", trend: "->", age: "1m",
                     isStale: false, dateString: "Apr 1", loopColor: .green)
    }
}

struct GlucoseTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> GlucoseEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (GlucoseEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GlucoseEntry>) -> Void) {
        let entry = makeEntry()
        let nextUpdate = Date().addingTimeInterval(5 * 60)
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func makeEntry() -> GlucoseEntry {
        let df = DateFormatter()
        df.dateFormat = "MMM d"
        let dateStr = df.string(from: Date())

        guard let data = SharedGlucoseData.read() else {
            return GlucoseEntry(date: Date(), glucose: "---", trend: "", age: "",
                               isStale: true, dateString: dateStr, loopColor: .gray)
        }

        let color: Color
        if let ld = data.loopLastRunDate {
            let la = Date().timeIntervalSince(ld)
            if la < 360 { color = .green }
            else if la < 900 { color = .yellow }
            else { color = .red }
        } else { color = .gray }

        return GlucoseEntry(
            date: Date(),
            glucose: data.isStale ? "---" : data.formattedGlucose,
            trend: data.isStale ? "" : (data.trendSymbol ?? ""),
            age: data.ageString,
            isStale: data.isStale,
            dateString: dateStr,
            loopColor: color
        )
    }
}

// MARK: - Views

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
                        .foregroundColor(entry.isStale ? .gray : .secondary)
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
            Text(entry.dateString + " | " + entry.age)
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
                HStack(spacing: 4) {
                    Circle().fill(entry.loopColor).frame(width: 8, height: 8)
                    Text(entry.glucose + entry.trend)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(entry.isStale ? .gray : .white)
                }
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

// MARK: - Widget

@main
struct GlucoseWidget: Widget {
    let kind = "GlucoseWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GlucoseTimelineProvider()) { entry in
            switch entry.date { // hack to get widget family
            default:
                GlucoseWidgetView(entry: entry)
            }
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
