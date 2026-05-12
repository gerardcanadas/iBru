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
    // Assertions are locale-independent: String(localized:) returns the active language's
    // translation, so tests check numeric values and structural invariants rather than
    // exact English strings.

    @Test func frequencySummary_everyNHours() {
        #expect(plan(frequency: .everyNHours, value: 8).frequencySummary.contains("8"))
    }

    @Test func frequencySummary_timesPerDay() {
        #expect(plan(frequency: .timesPerDay, value: 3).frequencySummary.contains("3"))
    }

    @Test func frequencySummary_everyNDays_one_usesSpecialForm() {
        // value:1 uses a special "daily" form; value:3 uses the "every N days" form
        let daily = plan(frequency: .everyNDays, value: 1).frequencySummary
        let multiDay = plan(frequency: .everyNDays, value: 3).frequencySummary
        #expect(daily != multiDay)
        #expect(!daily.contains("1"))  // "Daily"/"Diariamente" never contains the digit 1
    }

    @Test func frequencySummary_everyNDays_multiple() {
        #expect(plan(frequency: .everyNDays, value: 3).frequencySummary.contains("3"))
    }

    @Test func frequencySummary_specificDays_includesWeekdaySymbol() {
        // Weekday 4 = Wednesday; shortWeekdaySymbols[3] is locale-aware but calendar-stable
        let wednesday = Calendar.current.shortWeekdaySymbols[3]
        let p = plan(frequency: .specificDays, value: 1, weekdays: [4])
        #expect(p.frequencySummary.contains(wednesday))
    }

    @Test func frequencySummary_specificDays_multiple_includesCountAndWeekday() {
        let wednesday = Calendar.current.shortWeekdaySymbols[3]
        let p = plan(frequency: .specificDays, value: 2, weekdays: [4])
        #expect(p.frequencySummary.contains("2"))
        #expect(p.frequencySummary.contains(wednesday))
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

    // MARK: - durationSummary

    @Test func durationSummary_resolved_hasTwoParts() {
        let r = IllnessRecord(
            title: "Cold",
            startDate: Date.now.addingTimeInterval(-86400 * 5),
            endDate:   Date.now.addingTimeInterval(-86400)
        )
        context.insert(r)
        let parts = r.durationSummary.components(separatedBy: " \u{2013} ")
        #expect(parts.count == 2)
        #expect(!parts[0].isEmpty && !parts[1].isEmpty)
    }

    @Test func durationSummary_ongoing_secondPartDiffersFromDate() {
        // Locale-independent: the "ongoing" word (in any language) must differ from a
        // formatted end-date string, so both summaries share the em-dash separator but
        // produce different second parts.
        let ongoing = IllnessRecord(title: "Fever", startDate: Date.now, endDate: nil)
        let resolved = IllnessRecord(title: "Fever", startDate: Date.now, endDate: Date.now.addingTimeInterval(-86400))
        context.insert(ongoing)
        context.insert(resolved)
        let ongoingParts  = ongoing.durationSummary.components(separatedBy: " \u{2013} ")
        let resolvedParts = resolved.durationSummary.components(separatedBy: " \u{2013} ")
        #expect(ongoingParts.count == 2)
        #expect(resolvedParts.count == 2)
        #expect(ongoingParts[1] != resolvedParts[1])
    }

    // MARK: - isOngoing

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
