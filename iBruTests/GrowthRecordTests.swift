import Testing
import Foundation
import SwiftData
@testable import iBru

@Suite @MainActor
struct GrowthRecordTests {

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

    private func record(
        weightKg: Double? = nil,
        heightCm: Double? = nil,
        headCm: Double? = nil
    ) -> GrowthRecord {
        let r = GrowthRecord(weightKg: weightKg, heightCm: heightCm, headCircumferenceCm: headCm)
        context.insert(r)
        return r
    }

    private func baby() -> Baby {
        let b = Baby(name: "Pau", birthDate: Date.now.addingTimeInterval(-86400 * 90))
        context.insert(b)
        return b
    }

    // MARK: - summary

    @Test func summary_noMeasurements() {
        #expect(record().summary == String(localized: "No measurements"))
    }

    @Test func summary_weightOnly() {
        #expect(record(weightKg: 6.35).summary == "6.35 kg")
    }

    @Test func summary_heightOnly() {
        #expect(record(heightCm: 67.5).summary == "67.5 cm")
    }

    @Test func summary_headOnly() {
        #expect(record(headCm: 42.0).summary == "42.0 cm HC")
    }

    @Test func summary_allMeasurements() {
        let s = record(weightKg: 6.35, heightCm: 67.5, headCm: 42.0).summary
        #expect(s == "6.35 kg · 67.5 cm · 42.0 cm HC")
    }

    @Test func summary_weightAndHeight() {
        #expect(record(weightKg: 5.5, heightCm: 60.0).summary == "5.50 kg · 60.0 cm")
    }

    // MARK: - id

    @Test func id_isNonEmpty() {
        #expect(!record().id.isEmpty)
    }

    @Test func id_isUniquePerRecord() {
        #expect(record().id != record().id)
    }

    // MARK: - Baby relationship

    @Test func babyRelationship_canLink() throws {
        let b = baby()
        let r = record(weightKg: 6.0)
        r.baby = b

        try context.save()

        let fetched = try context.fetch(FetchDescriptor<GrowthRecord>())
        #expect(fetched.first?.baby?.name == "Pau")
    }

    @Test func babyRelationship_appearsInBabyGrowthRecords() throws {
        let b = baby()
        let r = record(weightKg: 6.0)
        r.baby = b

        try context.save()

        let fetchedBaby = try context.fetch(FetchDescriptor<Baby>()).first
        #expect(fetchedBaby?.growthRecords.contains { $0.id == r.id } == true)
    }

    @Test func babyDeletion_cascadesGrowthRecord() throws {
        let b = baby()
        let r = record(weightKg: 6.0)
        r.baby = b
        try context.save()

        context.delete(b)
        try context.save()

        let remaining = try context.fetch(FetchDescriptor<GrowthRecord>())
        #expect(remaining.isEmpty)
    }
}
