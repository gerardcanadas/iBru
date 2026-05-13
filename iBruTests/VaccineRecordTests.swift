import Testing
import Foundation
import SwiftData
@testable import iBru

@Suite @MainActor
struct VaccineRecordTests {

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

    private func vaccine(name: String = "MMR", days: Int = 365, givenDate: Date? = nil) -> VaccineRecord {
        let v = VaccineRecord(name: name, recommendedAgeDays: days, givenDate: givenDate)
        context.insert(v)
        return v
    }

    private func baby() -> Baby {
        let b = Baby(name: "Pau", birthDate: Date.now.addingTimeInterval(-86400 * 90))
        context.insert(b)
        return b
    }

    // MARK: - isReceived

    @Test func isReceived_falseWithoutGivenDate() {
        #expect(vaccine().isReceived == false)
    }

    @Test func isReceived_trueWithGivenDate() {
        #expect(vaccine(givenDate: .now).isReceived == true)
    }

    // MARK: - statusLabel

    @Test func statusLabel_upcoming() {
        #expect(vaccine().statusLabel == String(localized: "Upcoming"))
    }

    @Test func statusLabel_received() {
        #expect(vaccine(givenDate: .now).statusLabel == String(localized: "Received"))
    }

    // MARK: - recommendedAgeLabel

    @Test func recommendedAgeLabel_atBirth() {
        #expect(vaccine(days: 0).recommendedAgeLabel == String(localized: "At birth"))
    }

    @Test func recommendedAgeLabel_weeks() {
        #expect(vaccine(days: 7).recommendedAgeLabel == String(localized: "1 weeks"))
    }

    @Test func recommendedAgeLabel_months() {
        #expect(vaccine(days: 60).recommendedAgeLabel == String(localized: "2 months"))
    }

    @Test func recommendedAgeLabel_days() {
        let count = 5
        #expect(vaccine(days: count).recommendedAgeLabel == String(localized: "\(count) days"))
    }

    // MARK: - id

    @Test func id_isNonEmpty() {
        #expect(!vaccine().id.isEmpty)
    }

    @Test func id_isUniquePerVaccine() {
        #expect(vaccine().id != vaccine().id)
    }

    // MARK: - Baby relationship

    @Test func babyRelationship_canLink() throws {
        let b = baby()
        let v = vaccine()
        v.baby = b

        try context.save()

        let fetched = try context.fetch(FetchDescriptor<VaccineRecord>())
        #expect(fetched.first?.baby?.name == "Pau")
    }

    @Test func babyRelationship_appearsInBabyVaccines() throws {
        let b = baby()
        let v = vaccine()
        v.baby = b

        try context.save()

        let fetchedBaby = try context.fetch(FetchDescriptor<Baby>()).first
        #expect(fetchedBaby?.vaccines.contains { $0.id == v.id } == true)
    }

    @Test func babyDeletion_cascadesVaccine() throws {
        let b = baby()
        let v = vaccine()
        v.baby = b
        try context.save()

        context.delete(b)
        try context.save()

        let remaining = try context.fetch(FetchDescriptor<VaccineRecord>())
        #expect(remaining.isEmpty)
    }
}
