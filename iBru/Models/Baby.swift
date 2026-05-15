import SwiftData
import Foundation

enum BabySex: String, Codable, CaseIterable {
    case male, female
    var label: String { self == .male ? String(localized: "Male") : String(localized: "Female") }
}

@Model
final class Baby {
    var id: String = UUID().uuidString
    var name: String = ""
    var birthDate: Date = Date.now
    var colorHex: String = "#5B8DEF"
    var sex: BabySex = BabySex.male
    var isActive: Bool = true

    @Relationship(deleteRule: .cascade, inverse: \MedicationPlan.baby)
    var plans: [MedicationPlan] = []

    @Relationship(deleteRule: .cascade, inverse: \IllnessRecord.baby)
    var illnesses: [IllnessRecord] = []

    @Relationship(deleteRule: .cascade, inverse: \QuickDoseRecord.baby)
    var quickDoses: [QuickDoseRecord] = []

    @Relationship(deleteRule: .cascade, inverse: \VaccineRecord.baby)
    var vaccines: [VaccineRecord] = []

    @Relationship(deleteRule: .cascade, inverse: \GrowthRecord.baby)
    var growthRecords: [GrowthRecord] = []

    @Relationship(deleteRule: .cascade, inverse: \DailyNote.baby)
    var dailyNotes: [DailyNote] = []

    init(name: String, birthDate: Date, colorHex: String = "#5B8DEF") {
        self.name = name
        self.birthDate = birthDate
        self.colorHex = colorHex
    }

    var age: String {
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: birthDate, to: .now)
        if let years = comps.year, years > 0 {
            return "\(years)y \(comps.month ?? 0)m"
        } else if let months = comps.month, months > 0 {
            return "\(months) months"
        } else {
            return "\(comps.day ?? 0) days"
        }
    }
}
