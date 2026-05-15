import Testing
import Foundation
import SwiftData
@testable import iBru

@Suite @MainActor
struct DailyNoteTests {

    var container: ModelContainer
    var context: ModelContext

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: Baby.self, MedicationPlan.self, DoseRecord.self, IllnessRecord.self,
            QuickDoseRecord.self, TemperatureReading.self, VaccineRecord.self, GrowthRecord.self, DailyNote.self,
            configurations: config
        )
        context = ModelContext(container)
    }

    private func baby() -> Baby {
        let b = Baby(name: "Test", birthDate: .now)
        context.insert(b)
        return b
    }

    private func note(date: Date = .now, content: String = "Hello") -> DailyNote {
        let n = DailyNote(date: date, content: content)
        n.baby = baby()
        context.insert(n)
        return n
    }

    // MARK: - Date normalisation

    @Test func init_normalisesDateToStartOfDay() {
        let hour = Calendar.current.date(bySettingHour: 14, minute: 30, second: 0, of: .now)!
        let n = DailyNote(date: hour)
        let expected = Calendar.current.startOfDay(for: hour)
        #expect(n.date == expected)
    }

    @Test func init_midnightInput_remainsMidnight() {
        let midnight = Calendar.current.startOfDay(for: .now)
        let n = DailyNote(date: midnight)
        #expect(n.date == midnight)
    }

    // MARK: - Content

    @Test func init_storesContent() {
        let n = DailyNote(date: .now, content: "Slept well")
        #expect(n.content == "Slept well")
    }

    @Test func content_canBeUpdated() {
        let n = note(content: "First")
        n.content = "Updated"
        #expect(n.content == "Updated")
    }

    // MARK: - Baby relationship

    @Test func baby_relationshipRoundTrips() throws {
        let b = baby()
        let n = DailyNote(date: .now, content: "Hello")
        n.baby = b
        context.insert(n)
        try context.save()
        let fetched = try context.fetch(FetchDescriptor<DailyNote>())
        #expect(fetched.first?.baby?.name == "Test")
    }

    // MARK: - Date mutability

    @Test func date_canBeChangedToNewDay() {
        let n = note()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: .now))!
        n.date = tomorrow
        #expect(n.date == tomorrow)
    }
}
