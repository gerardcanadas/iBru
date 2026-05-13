import SwiftData
import Foundation

@Model
final class VaccineRecord {
    var id: String = UUID().uuidString
    var name: String = ""
    var recommendedAgeDays: Int = 0
    var givenDate: Date? = nil
    var notes: String = ""

    var baby: Baby?

    init(name: String, recommendedAgeDays: Int = 0, givenDate: Date? = nil, notes: String = "") {
        self.name = name
        self.recommendedAgeDays = recommendedAgeDays
        self.givenDate = givenDate
        self.notes = notes
    }

    var isReceived: Bool { givenDate != nil }

    var statusLabel: String {
        isReceived ? String(localized: "Received") : String(localized: "Upcoming")
    }

    var recommendedAgeLabel: String {
        guard recommendedAgeDays > 0 else { return String(localized: "At birth") }
        let months = recommendedAgeDays / 30
        if months >= 2 { return String(localized: "\(months) months") }
        let weeks = recommendedAgeDays / 7
        if weeks >= 1 { return String(localized: "\(weeks) weeks") }
        return String(localized: "\(recommendedAgeDays) days")
    }
}
