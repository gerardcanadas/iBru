import Testing
import Foundation
import SwiftData
@testable import iBru

@Suite @MainActor
struct DoseSchedulerTests {

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

    // MARK: - Helpers

    private var utc: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, hour h: Int = 0, minute mi: Int = 0) -> Date {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: mi))!
    }

    private func plan(
        frequency: FrequencyUnit,
        value: Int,
        start: Date,
        end: Date? = nil,
        weekdays: [Int] = [],
        stopped: Date? = nil,
        lastDoseDate: Date? = nil
    ) -> MedicationPlan {
        let p = MedicationPlan(
            medicationName: "Drug",
            doseAmount: 1,
            doseUnit: "ml",
            frequencyUnit: frequency,
            frequencyValue: value,
            startDate: start,
            endDate: end
        )
        p.weekdays = weekdays
        p.stoppedDate = stopped
        p.lastDoseDate = lastDoseDate
        context.insert(p)
        return p
    }

    // MARK: - everyNHours

    @Test func everyNHours_startAtMidnight_threeTimesInDay() {
        let start = date(2025, 1, 1)
        let p = plan(frequency: .everyNHours, value: 8, start: start)
        let times = DoseScheduler.scheduledTimes(for: p, on: start, calendar: utc)
        #expect(times.count == 3)
        #expect(times[0] == date(2025, 1, 1, hour: 0))
        #expect(times[1] == date(2025, 1, 1, hour: 8))
        #expect(times[2] == date(2025, 1, 1, hour: 16))
    }

    @Test func everyNHours_startAt8am_twoTimesInDay() {
        let start = date(2025, 1, 1, hour: 8)
        let p = plan(frequency: .everyNHours, value: 8, start: start)
        let times = DoseScheduler.scheduledTimes(for: p, on: start, calendar: utc)
        #expect(times.count == 2)
        #expect(times[0] == date(2025, 1, 1, hour: 8))
        #expect(times[1] == date(2025, 1, 1, hour: 16))
    }

    @Test func everyNHours_dayAfterStart_resumesFromMidnight() {
        let start = date(2025, 1, 1, hour: 8)
        let p = plan(frequency: .everyNHours, value: 8, start: start)
        let times = DoseScheduler.scheduledTimes(for: p, on: date(2025, 1, 2), calendar: utc)
        #expect(times.count == 3)
        #expect(times[0] == date(2025, 1, 2, hour: 0))
    }

    // MARK: - timesPerDay

    @Test func timesPerDay_single_scheduledAt8am() {
        let p = plan(frequency: .timesPerDay, value: 1, start: date(2025, 1, 1))
        let times = DoseScheduler.scheduledTimes(for: p, on: date(2025, 1, 1), calendar: utc)
        #expect(times.count == 1)
        #expect(utc.component(.hour, from: times[0]) == 8)
    }

    @Test func timesPerDay_three_distributedBetween8and22() {
        let p = plan(frequency: .timesPerDay, value: 3, start: date(2025, 1, 1))
        let times = DoseScheduler.scheduledTimes(for: p, on: date(2025, 1, 1), calendar: utc)
        #expect(times.count == 3)
        #expect(utc.component(.hour, from: times[0]) == 8)
        #expect(utc.component(.hour, from: times[2]) == 22)
    }

    // MARK: - specificDays

    @Test func specificDays_matchingWeekday_returnsTimes() {
        // 2025-01-01 is Wednesday = weekday 4
        let p = plan(frequency: .specificDays, value: 1, start: date(2025, 1, 1), weekdays: [4])
        let times = DoseScheduler.scheduledTimes(for: p, on: date(2025, 1, 1), calendar: utc)
        #expect(times.count == 1)
    }

    @Test func specificDays_nonMatchingWeekday_returnsEmpty() {
        // 2025-01-01 is Wednesday = weekday 4; exclude it
        let p = plan(frequency: .specificDays, value: 1, start: date(2025, 1, 1), weekdays: [2, 3, 5, 6, 7])
        let times = DoseScheduler.scheduledTimes(for: p, on: date(2025, 1, 1), calendar: utc)
        #expect(times.isEmpty)
    }

    // MARK: - everyNDays

    @Test func everyNDays_startDay_matches() {
        let start = date(2025, 1, 1, hour: 9)
        let p = plan(frequency: .everyNDays, value: 2, start: start)
        let times = DoseScheduler.scheduledTimes(for: p, on: date(2025, 1, 1), calendar: utc)
        #expect(times.count == 1)
        #expect(utc.component(.hour, from: times[0]) == 9)
    }

    @Test func everyNDays_dayOne_skipped() {
        let p = plan(frequency: .everyNDays, value: 2, start: date(2025, 1, 1, hour: 9))
        let times = DoseScheduler.scheduledTimes(for: p, on: date(2025, 1, 2), calendar: utc)
        #expect(times.isEmpty)
    }

    @Test func everyNDays_dayTwo_matches() {
        let p = plan(frequency: .everyNDays, value: 2, start: date(2025, 1, 1, hour: 9))
        let times = DoseScheduler.scheduledTimes(for: p, on: date(2025, 1, 3), calendar: utc)
        #expect(times.count == 1)
    }

    // MARK: - Guard conditions

    @Test func stoppedPlan_returnsEmpty() {
        let start = date(2025, 1, 1)
        let p = plan(frequency: .timesPerDay, value: 2, start: start, stopped: start)
        let times = DoseScheduler.scheduledTimes(for: p, on: start, calendar: utc)
        #expect(times.isEmpty)
    }

    @Test func planStartsInFuture_returnsEmpty() {
        let p = plan(frequency: .timesPerDay, value: 2, start: date(2025, 1, 10))
        let times = DoseScheduler.scheduledTimes(for: p, on: date(2025, 1, 1), calendar: utc)
        #expect(times.isEmpty)
    }

    @Test func planEndedBeforeDay_returnsEmpty() {
        let p = plan(frequency: .timesPerDay, value: 2, start: date(2025, 1, 1), end: date(2025, 1, 5))
        let times = DoseScheduler.scheduledTimes(for: p, on: date(2025, 1, 10), calendar: utc)
        #expect(times.isEmpty)
    }

    // MARK: - isMatch

    @Test func isMatch_withinOneMinute_returnsTrue() {
        let a = date(2025, 1, 1, hour: 8)
        let b = a.addingTimeInterval(59)
        #expect(DoseScheduler.isMatch(a, b))
    }

    @Test func isMatch_exactlyOneMinute_returnsFalse() {
        let a = date(2025, 1, 1, hour: 8)
        let b = a.addingTimeInterval(60)
        #expect(!DoseScheduler.isMatch(a, b))
    }

    // MARK: - lastDoseDate filter

    @Test func lastDoseDate_onSameDay_truncatesLaterSlots() {
        // Plan every 8h starting midnight: slots at 00:00, 08:00, 16:00
        // lastDoseDate = 08:00 → only 00:00 and 08:00 should be returned
        let day = date(2025, 3, 1)
        let lastDose = date(2025, 3, 1, hour: 8)
        let p = plan(frequency: .everyNHours, value: 8, start: day, lastDoseDate: lastDose)
        let times = DoseScheduler.scheduledTimes(for: p, on: day, calendar: utc)
        #expect(times.count == 2)
        #expect(times.last == lastDose)
    }

    @Test func lastDoseDate_dayAfterLastDoseDay_returnsEmpty() {
        // lastDoseDate was yesterday (March 1); any day AFTER that day should produce no slots.
        // This prevents stale notifications firing after a course completes when endDate is
        // in the future but the actual last dose slot has already passed.
        let yesterday = date(2025, 3, 1)
        let today     = date(2025, 3, 2)
        let lastDose  = date(2025, 3, 1, hour: 8)
        let p = plan(frequency: .everyNHours, value: 8, start: yesterday,
                     end: date(2025, 3, 4),          // endDate still in future
                     lastDoseDate: lastDose)
        let times = DoseScheduler.scheduledTimes(for: p, on: today, calendar: utc)
        #expect(times.isEmpty,
                "Day after lastDoseDate should return no slots even when endDate is in the future")
    }

    @Test func lastDoseDate_dayBeforeLastDoseDay_isUnaffected() {
        // lastDoseDate is March 3; computing slots for March 2 should be unaffected.
        let march2    = date(2025, 3, 2)
        let lastDose  = date(2025, 3, 3, hour: 8)
        let p = plan(frequency: .everyNHours, value: 8, start: date(2025, 3, 1),
                     end: date(2025, 3, 3),
                     lastDoseDate: lastDose)
        let times = DoseScheduler.scheduledTimes(for: p, on: march2, calendar: utc)
        #expect(times.count == 3, "Days before lastDoseDate's day should produce the full slot set")
    }

    @Test func lastDoseDate_exactlyAtLastSlot_includesThatSlot() {
        // lastDoseDate = 16:00; the 16:00 slot is within the 60s window
        let day = date(2025, 3, 1)
        let lastDose = date(2025, 3, 1, hour: 16)
        let p = plan(frequency: .everyNHours, value: 8, start: day, lastDoseDate: lastDose)
        let times = DoseScheduler.scheduledTimes(for: p, on: day, calendar: utc)
        #expect(times.contains(lastDose))
    }

    // MARK: - nextSlot skipped exclusion
    // These tests use Calendar.current (not UTC) to match nextSlot's internal calendar.

    @Test func nextSlot_skippedRecord_isExcluded() {
        // Plan with one slot tomorrow; marking it skipped → nextSlot returns nil.
        let cal = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: .now))!
        let p = plan(frequency: .timesPerDay, value: 1, start: tomorrow)
        let slot = DoseScheduler.scheduledTimes(for: p, on: tomorrow).first!
        let skipped = DoseRecord(scheduledDate: slot, status: .skipped)
        skipped.plan = p
        context.insert(skipped)
        #expect(DoseScheduler.nextSlot(for: [p]) == nil)
    }

    @Test func nextSlot_noSkippedRecord_returnsNextSlot() {
        // Plan with one slot tomorrow and no records → nextSlot returns that slot.
        let cal = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: .now))!
        let p = plan(frequency: .timesPerDay, value: 1, start: tomorrow)
        let slot = DoseScheduler.scheduledTimes(for: p, on: tomorrow).first!
        let result = DoseScheduler.nextSlot(for: [p])
        #expect(result?.scheduledTime == slot)
    }
}
