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
        GlucoseEntry(date: Date(), glucose: "120", age: "1m", isStale: false, dateString: "Apr 1")
    }
}

struct GlucoseTimelineProvider: TimelineProvider {
    let healthStore = HKHealthStore()
    let glucoseType = HKQuantityType.quantityType(forIdentifier: .bloodGlucose)!

    func placeholder(in context: Context) -> GlucoseEntry { .placeholder }
    func getSnapshot(in context: Context, completion: @escaping (GlucoseEntry) -> Void) {
        fetchLatestGlucose(completion: completion)
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<GlucoseEntry>) -> Void) {
        fetchLatestGlucose { entry in
            let next = Date().addingTimeInterval(5 * 60)
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }

    private func fetchLatestGlucose(completion: @escaping (GlucoseEntry) -> Void) {
        let df = DateFormatter(); df.dateFormat = "MMM d"
        let dateStr = df.string(from: Date())
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let q = HKSampleQuery(sampleType: glucoseType, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
            guard let s = samples?.first as? HKQuantitySample else {
                completion(GlucoseEntry(date: Date(), glucose: "---", age: "", isStale: true, dateString: dateStr))
                return
            }
            let val = String(format: "%.0f", s.quantity.doubleValue(for: .init(from: "mg/dL")))
            let sec = Date().timeIntervalSince(s.endDate)
            let stale = sec > 360
            let min = Int(sec / 60)
            let age: String
            if min < 1 { age = "now" }
            else if min < 60 { age = "\(min)m" }
            else { age = "\(min/60)h\(min%60)m" }
            completion(GlucoseEntry(date: Date(), glucose: stale ? "---" : val, age: age, isStale: stale, dateString: dateStr))
        }
        healthStore.execute(q)
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
                    Text(entry.age).font(.system(size: 9, design: .rounded)).foregroundColor(.secondary)
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
            Text("\(entry.dateString) | \(entry.age)").font(.system(size: 10)).foregroundColor(.secondary)
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
                    Text(entry.dateString); Text("|")
                    Text(entry.age).foregroundColor(entry.isStale ? .red : .secondary)
                }.font(.system(size: 11)).foregroundColor(.secondary)
            }
            Spacer()
        }
    }
}

struct InlineView: View {
    let entry: GlucoseEntry
    var body: some View { Text("\(entry.glucose) | \(entry.dateString) | \(entry.age)") }
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
