import SwiftData
import Foundation

enum FrequencyUnit: String, Codable, CaseIterable {
    case everyNHours = "Every N hours"
    case timesPerDay = "Times per day"
}

@Model
final class MedicationPlan {
    var medicationName: String
    var doseAmount: Double
    var doseUnit: String
    var frequencyUnit: FrequencyUnit
    var frequencyValue: Int
    var startDate: Date
    var endDate: Date?
    var notes: String

    var baby: Baby?

    @Relationship(deleteRule: .cascade, inverse: \DoseRecord.plan)
    var records: [DoseRecord] = []

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
        let now = Date.now
        let today = Calendar.current.startOfDay(for: now)
        guard startDate <= today.addingTimeInterval(86400) else { return false }
        if let end = endDate { return end >= today }
        return true
    }

    var frequencySummary: String {
        switch frequencyUnit {
        case .everyNHours:
            return "Every \(frequencyValue)h"
        case .timesPerDay:
            return "\(frequencyValue)×/day"
        }
    }

    var doseSummary: String {
        let formatted = doseAmount.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(doseAmount))
            : String(format: "%.1f", doseAmount)
        return "\(formatted) \(doseUnit)"
    }
}
