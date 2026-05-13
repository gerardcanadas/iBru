import Testing
import Foundation
import SwiftData
@testable import iBru

@Suite @MainActor
struct TemperatureReadingTests {

    var container: ModelContainer
    var context: ModelContext

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: Baby.self, MedicationPlan.self, DoseRecord.self, IllnessRecord.self, QuickDoseRecord.self,
            TemperatureReading.self, VaccineRecord.self, GrowthRecord.self,
            configurations: config
        )
        context = ModelContext(container)
    }

    private func reading(celsius: Double, notes: String = "") -> TemperatureReading {
        let r = TemperatureReading(valueCelsius: celsius, notes: notes)
        context.insert(r)
        return r
    }

    private func illness() -> IllnessRecord {
        let i = IllnessRecord(title: "Cold")
        context.insert(i)
        return i
    }

    // MARK: - displayValue

    @Test func displayValue_formatsToOneDecimal() {
        #expect(reading(celsius: 37.0).displayValue == "37.0 °C")
    }

    @Test func displayValue_highFever() {
        #expect(reading(celsius: 38.9).displayValue == "38.9 °C")
    }

    // MARK: - feverLabel

    @Test func feverLabel_normal_isNil() {
        #expect(reading(celsius: 37.4).feverLabel == nil)
    }

    @Test func feverLabel_lowFever() {
        #expect(reading(celsius: 37.5).feverLabel == String(localized: "Low fever"))
    }

    @Test func feverLabel_fever() {
        #expect(reading(celsius: 38.0).feverLabel == String(localized: "Fever"))
    }

    @Test func feverLabel_highFever() {
        #expect(reading(celsius: 38.5).feverLabel == String(localized: "High fever"))
    }

    @Test func feverLabel_boundary_37_5_isLowFever() {
        #expect(reading(celsius: 37.5).feverLabel == String(localized: "Low fever"))
    }

    @Test func feverLabel_boundary_38_0_isFever() {
        #expect(reading(celsius: 38.0).feverLabel == String(localized: "Fever"))
    }

    @Test func feverLabel_boundary_38_5_isHighFever() {
        #expect(reading(celsius: 38.5).feverLabel == String(localized: "High fever"))
    }

    // MARK: - id

    @Test func id_isNonEmpty() {
        #expect(!reading(celsius: 37.0).id.isEmpty)
    }

    @Test func id_isUniquePerReading() {
        #expect(reading(celsius: 37.0).id != reading(celsius: 37.0).id)
    }

    // MARK: - Illness relationship

    @Test func illnessRelationship_canLink() throws {
        let i = illness()
        let r = reading(celsius: 38.2)
        r.illness = i

        try context.save()

        let fetched = try context.fetch(FetchDescriptor<TemperatureReading>())
        #expect(fetched.first?.illness?.title == "Cold")
    }

    @Test func illnessRelationship_appearsInIllnessTemperatures() throws {
        let i = illness()
        let r = reading(celsius: 38.2)
        r.illness = i

        try context.save()

        let fetchedIllness = try context.fetch(FetchDescriptor<IllnessRecord>()).first
        #expect(fetchedIllness?.temperatures.contains { $0.id == r.id } == true)
    }

    @Test func illnessDeletion_cascadesTemperatureReading() throws {
        let i = illness()
        let r = reading(celsius: 38.2)
        r.illness = i
        try context.save()

        context.delete(i)
        try context.save()

        let remaining = try context.fetch(FetchDescriptor<TemperatureReading>())
        #expect(remaining.isEmpty)
    }
}
