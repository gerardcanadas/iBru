import Testing
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
        stopped: Date? = nil
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
}
