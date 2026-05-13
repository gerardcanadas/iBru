import SwiftData
import Foundation

@Model
final class IllnessRecord {
    var id: String = UUID().uuidString
    var title: String = ""
    var startDate: Date = Date.now
    var endDate: Date?
    var notes: String = ""

    var baby: Baby?

    @Relationship
    var plans: [MedicationPlan] = []

    @Relationship(deleteRule: .cascade, inverse: \TemperatureReading.illness)
    var temperatures: [TemperatureReading] = []

    init(title: String = "", startDate: Date = .now, endDate: Date? = nil, notes: String = "") {
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.notes = notes
    }

    var isOngoing: Bool {
        guard let end = endDate else { return true }
        let today = Calendar.current.startOfDay(for: .now)
        let endDay = Calendar.current.startOfDay(for: end)
        return endDay > today
    }

    var durationSummary: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let start = formatter.string(from: startDate)
        if let end = endDate {
            return "\(start) – \(formatter.string(from: end))"
        }
        return "\(start) – \(String(localized: "ongoing"))"
    }
}
