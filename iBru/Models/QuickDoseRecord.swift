import SwiftData
import Foundation

@Model
final class QuickDoseRecord {
    var id: String = UUID().uuidString
    var medicationName: String = ""
    var doseAmount: Double = 0
    var doseUnit: String = "ml"
    var givenAt: Date = Date.now
    var notes: String = ""

    var baby: Baby?

    init(medicationName: String, doseAmount: Double, doseUnit: String,
         givenAt: Date = .now, notes: String = "") {
        self.medicationName = medicationName
        self.doseAmount = doseAmount
        self.doseUnit = doseUnit
        self.givenAt = givenAt
        self.notes = notes
    }

    var doseSummary: String {
        let formatted = doseAmount.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(doseAmount))
            : String(format: "%.1f", doseAmount)
        return "\(formatted) \(doseUnit)"
    }

    var timeLabel: String {
        givenAt.formatted(date: .omitted, time: .shortened)
    }
}
