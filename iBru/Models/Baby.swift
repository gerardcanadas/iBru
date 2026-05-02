import SwiftData
import Foundation

@Model
final class Baby {
    var name: String
    var birthDate: Date
    var colorHex: String

    @Relationship(deleteRule: .cascade, inverse: \MedicationPlan.baby)
    var plans: [MedicationPlan] = []

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
