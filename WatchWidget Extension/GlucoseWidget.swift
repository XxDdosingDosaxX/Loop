import WidgetKit
import SwiftUI
import HealthKit

struct GlucoseEntry: TimelineEntry {
    let date: Date
    let glucose: String
    let age: String
    let isStale: Bool
    let dateString: String
    static var placeholder: GlucoseEntry {
        GlucoseEntry(date: Date(), glucose: "120", age: "1m", isStale: false, dateString: "Apr 2")
    }
}

struct GlucoseTimelineProvider: TimelineProvider {
    private let healthStore = HKHealthStore()
    private let glucoseType = HKQuantityType.quantityType(forIdentifier: .bloodGlucose)!

    /// Glucose older than 15 minutes is stale.
    /// CGM readings come every 5 min; 15 min gives a 3x buffer for
    /// WidgetKit refresh delays on watchOS.
    private let stalenessInterval: TimeInterval = 15 * 60

    func placeholder(in context: Context) -> GlucoseEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (GlucoseEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
            return
        }
        fetchLatestGlucose(completion: completion)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GlucoseEntry>) -> Void) {
        fetchLatestGlucose { entry in
            var entries: [GlucoseEntry] = [entry]

            // If showing valid glucose, add a future "stale" entry so the
            // widget transitions to "---" automatically even if WidgetKit
            // doesn't refresh on time.
            if !entry.isStale {
                let df = DateFormatter(); df.dateFormat = "MMM d"
                let staleDate = Date().addingTimeInterval(self.stalenessInterval)
                entries.append(GlucoseEntry(
                    date: staleDate,
                    glucose: "---",
                    age: "",
                    isStale: true,
                    dateString: df.string(from: staleDate)
                ))
            }

            // Request refresh in 5 minutes
            let refreshDate = Date().addingTimeInterval(5 * 60)
            completion(Timeline(entries: entries, policy: .after(refreshDate)))
        }
    }

    private func fetchLatestGlucose(completion: @escaping (GlucoseEntry) -> Void) {
        let df = DateFormatter(); df.dateFormat = "MMM d"
        let dateStr = df.string(from: Date())

        let staleEntry = GlucoseEntry(
            date: Date(), glucose: "---", age: "", isStale: true, dateString: dateStr
        )

        guard HKHealthStore.isHealthDataAvailable() else {
            completion(staleEntry)
            return
        }

        // Only look back 20 minutes for efficiency
        let predicate = HKQuery.predicateForSamples(
            withStart: Date().addingTimeInterval(-20 * 60),
            end: nil,
            options: .strictStartDate
        )
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        let query = HKSampleQuery(
            sampleType: glucoseType,
            predicate: predicate,
            limit: 1,
            sortDescriptors: [sort]
        ) { _, samples, _ in
            guard let sample = samples?.first as? HKQuantitySample else {
                completion(staleEntry)
                return
            }

            let mgdl = HKUnit.gramUnit(with: .milli).unitDivided(by: .literUnit(with: .deci))
            let value = String(format: "%.0f", sample.quantity.doubleValue(for: mgdl))

            let sampleAge = Date().timeIntervalSince(sample.endDate)
            let isStale = sampleAge > self.stalenessInterval

            let minutes = Int(sampleAge / 60)
            let age: String
            if minutes < 1 { age = "now" }
            else if minutes < 60 { age = "\(minutes)m" }
            else { age = "\(minutes / 60)h\(minutes % 60)m" }

            completion(GlucoseEntry(
                date: Date(),
                glucose: isStale ? "---" : value,
                age: age,
                isStale: isStale,
                dateString: dateStr
            ))
        }

        healthStore.execute(query)
    }
}

struct CircularView: View {
    let entry: GlucoseEntry
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Text(entry.glucose)
                    .font(.system(size: entry.glucose.count > 3 ? 14 : 16, weight: .bold, design: .rounded))
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
            Text(entry.glucose)
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
                Text(entry.glucose)
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
        Text("\(entry.glucose) | \(entry.dateString) | \(entry.age)")
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
