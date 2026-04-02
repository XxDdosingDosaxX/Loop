import Foundation

struct SharedGlucoseData: Codable {
    let glucoseValue: Double
    let glucoseDate: Date
    let trendSymbol: String?
    let unit: String
    let loopLastRunDate: Date?
    let eventualGlucose: Double?
    let isClosedLoop: Bool

    static let defaultsKey = "SharedGlucoseData"
    static let suiteName = "group.com.loopkit.Loop.WatchWidget"

    static func write(_ data: SharedGlucoseData) {
        let defaults = UserDefaults(suiteName: suiteName) ?? UserDefaults.standard
        if let encoded = try? JSONEncoder().encode(data) {
            defaults.set(encoded, forKey: defaultsKey)
            defaults.synchronize()
        }
    }

    static func read() -> SharedGlucoseData? {
        let defaults = UserDefaults(suiteName: suiteName) ?? UserDefaults.standard
        guard let data = defaults.data(forKey: defaultsKey),
              let glucose = try? JSONDecoder().decode(SharedGlucoseData.self, from: data) else {
            return nil
        }
        return glucose
    }

    var formattedGlucose: String {
        if unit == "mmol/L" {
            return String(format: "%.1f", glucoseValue / 18.0)
        }
        return String(format: "%.0f", glucoseValue)
    }

    var age: TimeInterval { Date().timeIntervalSince(glucoseDate) }
    var isStale: Bool { age > 6 * 60 }

    var ageString: String {
        let minutes = Int(age / 60)
        if minutes < 1 { return "now" }
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        let mins = minutes % 60
        return "\(hours)h\(mins)m"
    }
}
