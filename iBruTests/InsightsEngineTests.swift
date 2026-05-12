import Testing
import Foundation
@testable import iBru

// No @MainActor, no ModelContainer — InsightsEngine is pure logic.

@Suite
struct InsightsEngineTests {

    // MARK: - Helpers

    private var utc: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, hour h: Int = 12) -> Date {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    private func event(
        id: String = UUID().uuidString,
        name: String = "Paracetamol",
        date: Date,
        status: MedicationEventStatus = .taken,
        dose: String = "5 ml"
    ) -> MedicationEvent {
        MedicationEvent(id: id, date: date, status: status, medicationName: name, doseSummary: dose)
    }

    private func illness(
        id: String = UUID().uuidString,
        title: String = "Cold",
        start: Date,
        end: Date? = nil
    ) -> IllnessSnapshot {
        let cal = Calendar.current
        let ongoing: Bool
        if let e = end {
            ongoing = cal.startOfDay(for: e) > cal.startOfDay(for: Date.now)
        } else {
            ongoing = true
        }
        return IllnessSnapshot(
            id: id, title: title,
            startDate: start, endDate: end,
            durationSummary: end != nil ? "Jan 1 – Jan 5" : "Jan 1 – ongoing",
            isOngoing: ongoing
        )
    }

    // MARK: - dateRange(for:)
    // Tests verify containment rather than exact bounds to avoid timezone sensitivity.

    @Test func last7Days_containsRecentDate() {
        let now = Date.now
        let range = InsightsEngine.dateRange(for: .last7Days, now: now)
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: now)!
        let tenDaysAgo   = Calendar.current.date(byAdding: .day, value: -10, to: now)!
        #expect(range.contains(threeDaysAgo))
        #expect(!range.contains(tenDaysAgo))
        #expect(range.upperBound == now)
    }

    @Test func lastMonth_containsRecentDate() {
        let now = Date.now
        let range = InsightsEngine.dateRange(for: .lastMonth, now: now)
        let twoWeeksAgo  = Calendar.current.date(byAdding: .day,   value: -14, to: now)!
        let fortyDaysAgo = Calendar.current.date(byAdding: .day,   value: -40, to: now)!
        #expect(range.contains(twoWeeksAgo))
        #expect(!range.contains(fortyDaysAgo))
    }

    @Test func last3Months_containsRecentDate() {
        let now = Date.now
        let range = InsightsEngine.dateRange(for: .last3Months, now: now)
        let sixWeeksAgo   = Calendar.current.date(byAdding: .weekOfYear, value: -6, to: now)!
        let fourMonthsAgo = Calendar.current.date(byAdding: .month, value: -4, to: now)!
        #expect(range.contains(sixWeeksAgo))
        #expect(!range.contains(fourMonthsAgo))
    }

    @Test func lastYear_containsRecentDate() {
        let now = Date.now
        let range = InsightsEngine.dateRange(for: .lastYear, now: now)
        let sixMonthsAgo   = Calendar.current.date(byAdding: .month, value: -6, to: now)!
        let fourteenMonthsAgo = Calendar.current.date(byAdding: .month, value: -14, to: now)!
        #expect(range.contains(sixMonthsAgo))
        #expect(!range.contains(fourteenMonthsAgo))
    }

    @Test func allTime_containsDistantDates() {
        let range = InsightsEngine.dateRange(for: .allTime)
        #expect(range.contains(date(1900, 1, 1)))
        #expect(range.contains(date(2100, 1, 1)))
    }

    // MARK: - medicationInsights: keyword filtering

    @Test func medicationInsights_keyword_caseInsensitiveMatch() {
        let e = event(name: "Paracetamol", date: date(2025, 5, 1))
        let result = InsightsEngine.medicationInsights(
            events: [e], keyword: "paracetamol",
            range: Date.distantPast...Date.distantFuture
        )
        #expect(result.events.count == 1)
    }

    @Test func medicationInsights_keyword_diacriticInsensitiveMatch() {
        let e = event(name: "Ibuprofén", date: date(2025, 5, 1))
        let result = InsightsEngine.medicationInsights(
            events: [e], keyword: "ibuprofen",
            range: Date.distantPast...Date.distantFuture
        )
        #expect(result.events.count == 1)
    }

    @Test func medicationInsights_keyword_noMatch_returnsEmpty() {
        let e = event(name: "Paracetamol", date: date(2025, 5, 1))
        let result = InsightsEngine.medicationInsights(
            events: [e], keyword: "Xyz",
            range: Date.distantPast...Date.distantFuture
        )
        #expect(result.events.isEmpty)
    }

    @Test func medicationInsights_emptyKeyword_matchesAll() {
        let events = [
            event(name: "Paracetamol", date: date(2025, 5, 1)),
            event(name: "Ibuprofen",   date: date(2025, 5, 2))
        ]
        let result = InsightsEngine.medicationInsights(
            events: events, keyword: "",
            range: Date.distantPast...Date.distantFuture
        )
        #expect(result.events.count == 2)
    }

    // MARK: - medicationInsights: date range filtering

    @Test func medicationInsights_eventInRange_included() {
        let d = date(2025, 5, 10)
        let range = date(2025, 5, 1)...date(2025, 5, 31)
        let result = InsightsEngine.medicationInsights(events: [event(date: d)], keyword: "", range: range)
        #expect(result.events.count == 1)
    }

    @Test func medicationInsights_eventBeforeRange_excluded() {
        let d = date(2025, 4, 30)
        let range = date(2025, 5, 1)...date(2025, 5, 31)
        let result = InsightsEngine.medicationInsights(events: [event(date: d)], keyword: "", range: range)
        #expect(result.events.isEmpty)
    }

    @Test func medicationInsights_eventAfterRange_excluded() {
        let d = date(2025, 6, 1)
        let range = date(2025, 5, 1)...date(2025, 5, 31)
        let result = InsightsEngine.medicationInsights(events: [event(date: d)], keyword: "", range: range)
        #expect(result.events.isEmpty)
    }

    // MARK: - medicationInsights: counts

    @Test func medicationInsights_takenCount_correct() {
        let events = [
            event(date: date(2025, 5, 1), status: .taken),
            event(date: date(2025, 5, 2), status: .taken),
            event(date: date(2025, 5, 3), status: .taken)
        ]
        let result = InsightsEngine.medicationInsights(events: events, keyword: "", range: Date.distantPast...Date.distantFuture)
        #expect(result.takenCount == 3)
    }

    @Test func medicationInsights_skippedCount_correct() {
        let events = [
            event(date: date(2025, 5, 1), status: .skipped),
            event(date: date(2025, 5, 2), status: .skipped)
        ]
        let result = InsightsEngine.medicationInsights(events: events, keyword: "", range: Date.distantPast...Date.distantFuture)
        #expect(result.skippedCount == 2)
    }

    @Test func medicationInsights_quickDoseCount_correct() {
        let e = event(date: date(2025, 5, 1), status: .quick)
        let result = InsightsEngine.medicationInsights(events: [e], keyword: "", range: Date.distantPast...Date.distantFuture)
        #expect(result.quickDoseCount == 1)
    }

    @Test func medicationInsights_mixed_countsAreIndependent() {
        let events = [
            event(date: date(2025, 5, 1), status: .taken),
            event(date: date(2025, 5, 2), status: .taken),
            event(date: date(2025, 5, 3), status: .skipped),
            event(date: date(2025, 5, 4), status: .quick),
            event(date: date(2025, 5, 5), status: .quick),
            event(date: date(2025, 5, 6), status: .quick)
        ]
        let result = InsightsEngine.medicationInsights(events: events, keyword: "", range: Date.distantPast...Date.distantFuture)
        #expect(result.takenCount == 2)
        #expect(result.skippedCount == 1)
        #expect(result.quickDoseCount == 3)
    }

    @Test func medicationInsights_eventsSortedAscendingByDate() {
        let events = [
            event(date: date(2025, 5, 3)),
            event(date: date(2025, 5, 1)),
            event(date: date(2025, 5, 2))
        ]
        let result = InsightsEngine.medicationInsights(events: events, keyword: "", range: Date.distantPast...Date.distantFuture)
        let dates = result.events.map { $0.date }
        #expect(dates == dates.sorted())
    }

    @Test func medicationInsights_firstAndLastDate_correct() {
        let d1 = date(2025, 5, 1)
        let d2 = date(2025, 5, 15)
        let d3 = date(2025, 5, 31)
        let events = [event(date: d2), event(date: d1), event(date: d3)]
        let result = InsightsEngine.medicationInsights(events: events, keyword: "", range: Date.distantPast...Date.distantFuture)
        #expect(result.firstDate == d1)
        #expect(result.lastDate == d3)
    }

    // MARK: - illnessInsights: keyword filtering

    @Test func illnessInsights_keyword_caseInsensitiveMatch() {
        let i = illness(title: "Cold", start: date(2025, 5, 1))
        let result = InsightsEngine.illnessInsights(illnesses: [i], keyword: "cold", range: Date.distantPast...Date.distantFuture)
        #expect(result.totalCount == 1)
    }

    @Test func illnessInsights_keyword_noMatch_returnsEmpty() {
        let i = illness(title: "Cold", start: date(2025, 5, 1))
        let result = InsightsEngine.illnessInsights(illnesses: [i], keyword: "Fever", range: Date.distantPast...Date.distantFuture)
        #expect(result.illnesses.isEmpty)
    }

    // MARK: - illnessInsights: date range filtering

    @Test func illnessInsights_startDateInRange_included() {
        let i = illness(start: date(2025, 5, 10), end: date(2025, 5, 12))
        let range = date(2025, 5, 1)...date(2025, 5, 31)
        let result = InsightsEngine.illnessInsights(illnesses: [i], keyword: "", range: range)
        #expect(result.totalCount == 1)
    }

    @Test func illnessInsights_startDateBeforeRange_excluded() {
        // Illness started before the range but ended within it — should still be excluded
        let i = illness(start: date(2025, 4, 28), end: date(2025, 5, 5))
        let range = date(2025, 5, 1)...date(2025, 5, 31)
        let result = InsightsEngine.illnessInsights(illnesses: [i], keyword: "", range: range)
        #expect(result.totalCount == 0)
    }

    // MARK: - illnessInsights: aggregation

    @Test func illnessInsights_longIllnessCount_4DayIllness_counted() {
        let i = illness(start: date(2025, 5, 1), end: date(2025, 5, 5)) // 4 days
        let result = InsightsEngine.illnessInsights(illnesses: [i], keyword: "", range: Date.distantPast...Date.distantFuture)
        #expect(result.longIllnessCount == 1)
    }

    @Test func illnessInsights_longIllnessCount_3DayIllness_notCounted() {
        let i = illness(start: date(2025, 5, 1), end: date(2025, 5, 4)) // exactly 3 days — not > 3
        let result = InsightsEngine.illnessInsights(illnesses: [i], keyword: "", range: Date.distantPast...Date.distantFuture)
        #expect(result.longIllnessCount == 0)
    }

    @Test func illnessInsights_longIllnessCount_ongoingExcluded() {
        let i = illness(start: date(2025, 5, 1), end: nil) // ongoing, duration unknown
        let result = InsightsEngine.illnessInsights(illnesses: [i], keyword: "", range: Date.distantPast...Date.distantFuture)
        #expect(result.longIllnessCount == 0)
    }

    @Test func illnessInsights_averageDuration_correct() {
        let i1 = illness(start: date(2025, 5, 1), end: date(2025, 5, 3))  // 2 days
        let i2 = illness(start: date(2025, 5, 10), end: date(2025, 5, 14)) // 4 days
        let result = InsightsEngine.illnessInsights(illnesses: [i1, i2], keyword: "", range: Date.distantPast...Date.distantFuture)
        #expect(result.averageDurationDays == 3.0)
    }

    @Test func illnessInsights_averageDuration_onlyResolved() {
        let resolved = illness(start: date(2025, 5, 1), end: date(2025, 5, 5)) // 4 days
        let ongoing  = illness(start: date(2025, 5, 10), end: nil)
        let result = InsightsEngine.illnessInsights(illnesses: [resolved, ongoing], keyword: "", range: Date.distantPast...Date.distantFuture)
        #expect(result.averageDurationDays == 4.0)
    }

    @Test func illnessInsights_averageDuration_noResolved_isZero() {
        let i = illness(start: date(2025, 5, 1), end: nil)
        let result = InsightsEngine.illnessInsights(illnesses: [i], keyword: "", range: Date.distantPast...Date.distantFuture)
        #expect(result.averageDurationDays == 0.0)
    }

    @Test func illnessInsights_illnessesSortedAscendingByStartDate() {
        let illnesses = [
            illness(start: date(2025, 5, 10)),
            illness(start: date(2025, 5, 1)),
            illness(start: date(2025, 5, 5))
        ]
        let result = InsightsEngine.illnessInsights(illnesses: illnesses, keyword: "", range: Date.distantPast...Date.distantFuture)
        let starts = result.illnesses.map { $0.startDate }
        #expect(starts == starts.sorted())
    }

    // MARK: - illnessDayIDs

    @Test func illnessDayIDs_empty_returnsEmpty() {
        #expect(InsightsEngine.illnessDayIDs(for: []).isEmpty)
    }

    @Test func illnessDayIDs_singleDayIllness_containsExactlyOneDay() {
        let i = illness(start: date(2025, 5, 10), end: date(2025, 5, 10))
        let ids = InsightsEngine.illnessDayIDs(for: [i], now: date(2025, 5, 15), calendar: utc)
        #expect(ids.count == 1)
        #expect(ids.contains(InsightsEngine.dayID(for: date(2025, 5, 10), calendar: utc)))
    }

    @Test func illnessDayIDs_multiDayIllness_containsEveryDay() {
        let i = illness(start: date(2025, 5, 1), end: date(2025, 5, 3))
        let ids = InsightsEngine.illnessDayIDs(for: [i], now: date(2025, 5, 15), calendar: utc)
        #expect(ids.count == 3)
        #expect(ids.contains(InsightsEngine.dayID(for: date(2025, 5, 1), calendar: utc)))
        #expect(ids.contains(InsightsEngine.dayID(for: date(2025, 5, 2), calendar: utc)))
        #expect(ids.contains(InsightsEngine.dayID(for: date(2025, 5, 3), calendar: utc)))
    }

    @Test func illnessDayIDs_ongoingIllness_includesThroughNow() {
        let i = illness(start: date(2025, 5, 3), end: nil)
        let now = date(2025, 5, 5)
        let ids = InsightsEngine.illnessDayIDs(for: [i], now: now, calendar: utc)
        #expect(ids.count == 3)
        #expect(ids.contains(InsightsEngine.dayID(for: date(2025, 5, 3), calendar: utc)))
        #expect(ids.contains(InsightsEngine.dayID(for: date(2025, 5, 4), calendar: utc)))
        #expect(ids.contains(InsightsEngine.dayID(for: date(2025, 5, 5), calendar: utc)))
    }

    @Test func illnessDayIDs_nonIllnessDay_notContained() {
        let i = illness(start: date(2025, 5, 1), end: date(2025, 5, 3))
        let ids = InsightsEngine.illnessDayIDs(for: [i], now: date(2025, 5, 15), calendar: utc)
        #expect(!ids.contains(InsightsEngine.dayID(for: date(2025, 5, 4), calendar: utc)))
    }

    // MARK: - illnessStartDayIDs

    @Test func illnessStartDayIDs_empty_returnsEmpty() {
        #expect(InsightsEngine.illnessStartDayIDs(for: []).isEmpty)
    }

    @Test func illnessStartDayIDs_returnsOnlyStartDays() {
        let i1 = illness(start: date(2025, 5, 1), end: date(2025, 5, 5))
        let i2 = illness(start: date(2025, 5, 10), end: date(2025, 5, 12))
        let ids = InsightsEngine.illnessStartDayIDs(for: [i1, i2], calendar: utc)
        #expect(ids.count == 2)
        #expect(ids.contains(InsightsEngine.dayID(for: date(2025, 5, 1),  calendar: utc)))
        #expect(ids.contains(InsightsEngine.dayID(for: date(2025, 5, 10), calendar: utc)))
        #expect(!ids.contains(InsightsEngine.dayID(for: date(2025, 5, 3), calendar: utc)))
    }
}
