import SwiftData
import Foundation

@Model
final class GrowthRecord {
    var id: String = UUID().uuidString
    var date: Date = Date.now
    var weightKg: Double? = nil
    var heightCm: Double? = nil
    var headCircumferenceCm: Double? = nil
    var notes: String = ""

    var baby: Baby?

    init(date: Date = .now, weightKg: Double? = nil, heightCm: Double? = nil, headCircumferenceCm: Double? = nil, notes: String = "") {
        self.date = date
        self.weightKg = weightKg
        self.heightCm = heightCm
        self.headCircumferenceCm = headCircumferenceCm
        self.notes = notes
    }

    var summary: String {
        var parts: [String] = []
        if let w = weightKg { parts.append(String(format: "%.2f kg", w)) }
        if let h = heightCm { parts.append(String(format: "%.1f cm", h)) }
        if let hc = headCircumferenceCm { parts.append(String(format: "%.1f cm HC", hc)) }
        return parts.isEmpty ? String(localized: "No measurements") : parts.joined(separator: " · ")
    }
}
