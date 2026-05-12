import SwiftData
import Foundation

enum FrequencyUnit: String, Codable, CaseIterable {
    case everyNHours = "Every N hours"
    case timesPerDay = "Times per day"
    case specificDays = "Specific days"
    case everyNDays   = "Every N days"
}

@Model
final class MedicationPlan {
    var id: String = UUID().uuidString
    var medicationName: String = ""
    var doseAmount: Double = 0
    var doseUnit: String = "ml"
    var frequencyUnit: FrequencyUnit = FrequencyUnit.everyNHours
    var frequencyValue: Int = 8
    var startDate: Date = Date.now
    var endDate: Date?
    var notes: String = ""
    var weekdays: [Int] = []   // Calendar weekday integers: 1=Sun, 2=Mon, … 7=Sat
    var stoppedDate: Date? = nil

    var baby: Baby?

    @Relationship(deleteRule: .cascade, inverse: \DoseRecord.plan)
    var records: [DoseRecord] = []

    @Relationship(inverse: \IllnessRecord.plans)
    var illnesses: [IllnessRecord] = []

    init(
        medicationName: String,
        doseAmount: Double,
        doseUnit: String,
        frequencyUnit: FrequencyUnit,
        frequencyValue: Int,
        startDate: Date,
        endDate: Date? = nil,
        notes: String = ""
    ) {
        self.medicationName = medicationName
        self.doseAmount = doseAmount
        self.doseUnit = doseUnit
        self.frequencyUnit = frequencyUnit
        self.frequencyValue = frequencyValue
        self.startDate = startDate
        self.endDate = endDate
        self.notes = notes
    }

    var isActive: Bool {
        if stoppedDate != nil { return false }
        let now = Date.now
        let today = Calendar.current.startOfDay(for: now)
        guard startDate <= today.addingTimeInterval(86400) else { return false }
        if let end = endDate { return end >= today }
        return true
    }

    var frequencySummary: String {
        switch frequencyUnit {
        case .everyNHours:
            return String(localized: "Every \(frequencyValue)h")
        case .timesPerDay:
            return String(localized: "\(frequencyValue)×/day")
        case .specificDays:
            let symbols = Calendar.current.shortWeekdaySymbols
            let names = weekdays.sorted()
                .compactMap { $0 >= 1 && $0 <= 7 ? symbols[$0 - 1] : nil }
                .joined(separator: "/")
            return frequencyValue == 1
                ? String(localized: "Once on \(names)")
                : String(localized: "\(frequencyValue)×/day on \(names)")
        case .everyNDays:
            return frequencyValue == 1
                ? String(localized: "Daily")
                : String(localized: "Every \(frequencyValue) days")
        }
    }

    var doseSummary: String {
        let formatted = doseAmount.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(doseAmount))
            : String(format: "%.1f", doseAmount)
        return "\(formatted) \(doseUnit)"
    }
}
