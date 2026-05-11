import Testing
import Foundation
import SwiftData
@testable import iBru

@Suite @MainActor
struct MedicationPlanTests {

    var container: ModelContainer
    var context: ModelContext

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: Baby.self, MedicationPlan.self, DoseRecord.self, IllnessRecord.self,
            configurations: config
        )
        context = ModelContext(container)
    }

    private func plan(
        frequency: FrequencyUnit = .everyNHours,
        value: Int = 8,
        amount: Double = 5,
        unit: String = "ml",
        weekdays: [Int] = [],
        startDate: Date = .now,
        endDate: Date? = nil,
        stopped: Date? = nil
    ) -> MedicationPlan {
        let p = MedicationPlan(
            medicationName: "Drug",
            doseAmount: amount,
            doseUnit: unit,
            frequencyUnit: frequency,
            frequencyValue: value,
            startDate: startDate,
            endDate: endDate
        )
        p.weekdays = weekdays
        p.stoppedDate = stopped
        context.insert(p)
        return p
    }

    // MARK: - doseSummary

    @Test func doseSummary_wholeNumber() {
        #expect(plan(amount: 5, unit: "ml").doseSummary == "5 ml")
    }

    @Test func doseSummary_decimal() {
        #expect(plan(amount: 2.5, unit: "ml").doseSummary == "2.5 ml")
    }

    @Test func doseSummary_smallDecimal() {
        #expect(plan(amount: 0.5, unit: "ml").doseSummary == "0.5 ml")
    }

    // MARK: - frequencySummary

    @Test func frequencySummary_everyNHours() {
        #expect(plan(frequency: .everyNHours, value: 8).frequencySummary == "Every 8h")
    }

    @Test func frequencySummary_timesPerDay() {
        #expect(plan(frequency: .timesPerDay, value: 3).frequencySummary == "3×/day")
    }

    @Test func frequencySummary_everyNDays_one_isDaily() {
        #expect(plan(frequency: .everyNDays, value: 1).frequencySummary == "Daily")
    }

    @Test func frequencySummary_everyNDays_multiple() {
        #expect(plan(frequency: .everyNDays, value: 3).frequencySummary == "Every 3 days")
    }

    @Test func frequencySummary_specificDays_once() {
        // Weekday 4 = Wednesday = "Wed" in en locale
        let p = plan(frequency: .specificDays, value: 1, weekdays: [4])
        #expect(p.frequencySummary.hasPrefix("Once on"))
    }

    @Test func frequencySummary_specificDays_multiple() {
        let p = plan(frequency: .specificDays, value: 2, weekdays: [4])
        #expect(p.frequencySummary.hasSuffix("Wed"))
        #expect(p.frequencySummary.contains("×/day"))
    }

    // MARK: - isActive

    @Test func isActive_stopped_returnsFalse() {
        #expect(plan(stopped: .now).isActive == false)
    }

    @Test func isActive_noEndDate_returnsTrue() {
        #expect(plan().isActive == true)
    }

    @Test func isActive_futureEndDate_returnsTrue() {
        let future = Date.now.addingTimeInterval(86400 * 7)
        #expect(plan(endDate: future).isActive == true)
    }

    @Test func isActive_pastEndDate_returnsFalse() {
        let past = Date.now.addingTimeInterval(-86400 * 2)
        #expect(plan(endDate: past).isActive == false)
    }
}

// MARK: - IllnessRecord

@Suite @MainActor
struct IllnessRecordTests {

    var container: ModelContainer
    var context: ModelContext

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: Baby.self, MedicationPlan.self, DoseRecord.self, IllnessRecord.self,
            configurations: config
        )
        context = ModelContext(container)
    }

    private func illness(endDate: Date? = nil) -> IllnessRecord {
        let r = IllnessRecord(title: "Cold", startDate: .now, endDate: endDate)
        context.insert(r)
        return r
    }

    @Test func isOngoing_noEndDate_returnsTrue() {
        #expect(illness().isOngoing == true)
    }

    @Test func isOngoing_futureEndDate_returnsTrue() {
        let future = Date.now.addingTimeInterval(86400 * 3)
        #expect(illness(endDate: future).isOngoing == true)
    }

    @Test func isOngoing_endedToday_returnsFalse() {
        // Same-day end means "ended today" — not still ongoing
        let todayStart = Calendar.current.startOfDay(for: .now)
        #expect(illness(endDate: todayStart).isOngoing == false)
    }

    @Test func isOngoing_pastEndDate_returnsFalse() {
        let yesterday = Date.now.addingTimeInterval(-86400)
        #expect(illness(endDate: yesterday).isOngoing == false)
    }
}
