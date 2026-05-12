import Foundation

// MARK: - Query configuration

enum InsightsQueryType: String, CaseIterable, Identifiable {
    case medications = "Medications"
    case illnesses   = "Illnesses"
    var id: String { rawValue }
}

enum InsightsPeriod: String, CaseIterable, Identifiable {
    case last7Days   = "Last 7 days"
    case lastMonth   = "Last month"
    case last3Months = "Last 3 months"
    case lastYear    = "Last year"
    case allTime     = "All time"
    var id: String { rawValue }
}

// MARK: - Medication types

enum MedicationEventStatus {
    case taken, skipped, quick
}

struct MedicationEvent: Identifiable {
    let id: String
    let date: Date
    let status: MedicationEventStatus
    let medicationName: String
    let doseSummary: String
}

struct MedicationInsightResult {
    let takenCount: Int
    let skippedCount: Int
    let quickDoseCount: Int
    let firstDate: Date?
    let lastDate: Date?
    let events: [MedicationEvent]
}

// MARK: - Illness types

struct IllnessSnapshot: Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date?
    let durationSummary: String
    let isOngoing: Bool
}

struct IllnessInsightResult {
    let totalCount: Int
    let longIllnessCount: Int
    let averageDurationDays: Double
    let illnesses: [IllnessSnapshot]
}

// MARK: - Engine

enum InsightsEngine {

    // MARK: - Calendar helpers

    /// Returns an integer key YYYYMMDD for a date, used for O(1) set membership checks.
    static func dayID(for date: Date, calendar: Calendar = .current) -> Int {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return (c.year ?? 0) * 10000 + (c.month ?? 0) * 100 + (c.day ?? 0)
    }

    /// Returns a set of YYYYMMDD keys for every calendar day covered by any illness.
    /// Ongoing illnesses (endDate == nil) are treated as running through `now`.
    static func illnessDayIDs(
        for illnesses: [IllnessSnapshot],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Set<Int> {
        var result = Set<Int>()
        for illness in illnesses {
            var day = calendar.startOfDay(for: illness.startDate)
            let end = calendar.startOfDay(for: illness.endDate ?? now)
            while day <= end {
                result.insert(dayID(for: day, calendar: calendar))
                guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
            }
        }
        return result
    }

    /// Returns a set of YYYYMMDD keys for illness start dates only.
    static func illnessStartDayIDs(
        for illnesses: [IllnessSnapshot],
        calendar: Calendar = .current
    ) -> Set<Int> {
        Set(illnesses.map { dayID(for: $0.startDate, calendar: calendar) })
    }

    // MARK: - Date range

    static func dateRange(for period: InsightsPeriod, now: Date = .now) -> ClosedRange<Date> {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        switch period {
        case .last7Days:
            return cal.date(byAdding: .day, value: -7, to: today)!...now
        case .lastMonth:
            return cal.date(byAdding: .month, value: -1, to: today)!...now
        case .last3Months:
            return cal.date(byAdding: .month, value: -3, to: today)!...now
        case .lastYear:
            return cal.date(byAdding: .year, value: -1, to: today)!...now
        case .allTime:
            return Date.distantPast...Date.distantFuture
        }
    }

    static func medicationInsights(
        events: [MedicationEvent],
        keyword: String,
        range: ClosedRange<Date>
    ) -> MedicationInsightResult {
        let filtered = events.filter { event in
            (keyword.isEmpty || event.medicationName.range(of: keyword, options: [.caseInsensitive, .diacriticInsensitive]) != nil)
            && range.contains(event.date)
        }
        let sorted = filtered.sorted { $0.date < $1.date }
        return MedicationInsightResult(
            takenCount:     sorted.filter { $0.status == .taken }.count,
            skippedCount:   sorted.filter { $0.status == .skipped }.count,
            quickDoseCount: sorted.filter { $0.status == .quick }.count,
            firstDate:      sorted.first?.date,
            lastDate:       sorted.last?.date,
            events:         sorted
        )
    }

    static func illnessInsights(
        illnesses: [IllnessSnapshot],
        keyword: String,
        range: ClosedRange<Date>
    ) -> IllnessInsightResult {
        let filtered = illnesses.filter { illness in
            (keyword.isEmpty || illness.title.range(of: keyword, options: [.caseInsensitive, .diacriticInsensitive]) != nil)
            && range.contains(illness.startDate)
        }
        let sorted = filtered.sorted { $0.startDate < $1.startDate }

        let cal = Calendar.current
        let longCount = sorted.filter { illness in
            guard let end = illness.endDate else { return false }
            let days = cal.dateComponents([.day], from: illness.startDate, to: end).day ?? 0
            return days > 3
        }.count

        let resolved = sorted.compactMap { illness -> Int? in
            guard let end = illness.endDate else { return nil }
            return cal.dateComponents([.day], from: illness.startDate, to: end).day
        }
        let avgDuration = resolved.isEmpty ? 0.0 : Double(resolved.reduce(0, +)) / Double(resolved.count)

        return IllnessInsightResult(
            totalCount:         sorted.count,
            longIllnessCount:   longCount,
            averageDurationDays: avgDuration,
            illnesses:          sorted
        )
    }
}
