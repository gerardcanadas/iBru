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
            let wakingStart = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: day)!
            let wakingEnd   = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: day)!
            let n = plan.frequencyValue
            guard n > 0 else { return [] }
            if n == 1 {
                times = [wakingStart]
            } else {
                let gap = wakingEnd.timeIntervalSince(wakingStart) / Double(n - 1)
                for i in 0..<n {
                    times.append(wakingStart.addingTimeInterval(Double(i) * gap))
                }
            }
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
}
