import SwiftData
import Foundation

@Model
final class TemperatureReading {
    var id: String = UUID().uuidString
    var date: Date = Date.now
    var valueCelsius: Double = 37.0
    var notes: String = ""

    var illness: IllnessRecord?

    init(date: Date = .now, valueCelsius: Double, notes: String = "") {
        self.date = date
        self.valueCelsius = valueCelsius
        self.notes = notes
    }

    var displayValue: String {
        String(format: "%.1f °C", valueCelsius)
    }

    var feverLabel: String? {
        if valueCelsius >= 38.5 { return String(localized: "High fever") }
        if valueCelsius >= 38.0 { return String(localized: "Fever") }
        if valueCelsius >= 37.5 { return String(localized: "Low fever") }
        return nil
    }
}
