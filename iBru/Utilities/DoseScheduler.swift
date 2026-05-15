import Foundation

struct ScheduledSlot: Identifiable {
    let id = UUID()
    let scheduledTime: Date
    let plan: MedicationPlan
}

enum DoseScheduler {

    static func scheduledTimes(for plan: MedicationPlan, on day: Date, calendar: Calendar = .current) -> [Date] {
        let dayStart = calendar.startOfDay(for: day)
        let dayEnd = dayStart.addingTimeInterval(86400)

        guard plan.startDate < dayEnd else { return [] }
        if let end = plan.endDate, end < dayStart { return [] }
        if plan.stoppedDate != nil { return [] }

        var times: [Date] = []

        switch plan.frequencyUnit {
        case .everyNHours:
            let interval = TimeInterval(plan.frequencyValue * 3600)
            let anchor = plan.startDate
            let secondsSinceAnchor = dayStart.timeIntervalSince(anchor)
            let steps = max(0, Int(ceil(secondsSinceAnchor / interval)))
            var t = anchor.addingTimeInterval(Double(steps) * interval)
            while t < dayEnd {
                if t >= dayStart { times.append(t) }
                t = t.addingTimeInterval(interval)
            }

        case .timesPerDay:
            times = distributedTimes(count: plan.frequencyValue, on: day, calendar: calendar)

        case .specificDays:
            let weekday = calendar.component(.weekday, from: day)
            guard plan.weekdays.contains(weekday) else { return [] }
            times = distributedTimes(count: plan.frequencyValue, on: day, calendar: calendar)

        case .everyNDays:
            let startDay = calendar.startOfDay(for: plan.startDate)
            let targetDay = calendar.startOfDay(for: day)
            guard let daysDiff = calendar.dateComponents([.day], from: startDay, to: targetDay).day,
                  daysDiff >= 0,
                  daysDiff % plan.frequencyValue == 0
            else { return [] }
            var comps = calendar.dateComponents([.year, .month, .day], from: day)
            let startTime = calendar.dateComponents([.hour, .minute], from: plan.startDate)
            comps.hour = startTime.hour
            comps.minute = startTime.minute
            if let date = calendar.date(from: comps) { times = [date] }
        }

        if let lastDose = plan.lastDoseDate, calendar.isDate(lastDose, inSameDayAs: day) {
            times = times.filter { $0 <= lastDose.addingTimeInterval(60) }
        }

        return times
    }

    static func nextSlot(for plans: [MedicationPlan], after now: Date = .now) -> ScheduledSlot? {
        let calendar = Calendar.current
        let days = [now, calendar.date(byAdding: .day, value: 1, to: now)!]
        let candidates = days.flatMap { day in
            plans.flatMap { plan in
                scheduledTimes(for: plan, on: day, calendar: calendar)
                    .filter { $0 > now }
                    .filter { slot in
                        let existing = plan.records.first(where: { isMatch($0.scheduledDate, slot) })
                        return existing?.status != .skipped
                    }
                    .map { ScheduledSlot(scheduledTime: $0, plan: plan) }
            }
        }
        return candidates.min(by: { $0.scheduledTime < $1.scheduledTime })
    }

    static func overdueTimes(for plan: MedicationPlan, asOf now: Date = .now) -> [Date] {
        scheduledTimes(for: plan, on: now).filter { slot in
            slot < now && !plan.records.contains(where: { isMatch($0.scheduledDate, slot) })
        }
    }

    static func record(for slot: Date, in plan: MedicationPlan) -> DoseRecord? {
        plan.records.first(where: { isMatch($0.scheduledDate, slot) })
    }

    static func isMatch(_ a: Date, _ b: Date) -> Bool {
        abs(a.timeIntervalSince(b)) < 60
    }

    private static func distributedTimes(count: Int, on date: Date, calendar: Calendar) -> [Date] {
        let wakingStart = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: date)!
        let wakingEnd   = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: date)!
        guard count > 0 else { return [] }
        if count == 1 { return [wakingStart] }
        let gap = wakingEnd.timeIntervalSince(wakingStart) / Double(count - 1)
        return (0..<count).map { wakingStart.addingTimeInterval(Double($0) * gap) }
    }
}
