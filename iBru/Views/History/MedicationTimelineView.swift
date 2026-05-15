import SwiftUI
import SwiftData

struct MedicationTimelineView: View {
    let baby: Baby
    let medicationName: String

    // MARK: - Internal types

    private struct SlotEntry: Identifiable {
        let id = UUID()
        let time: Date
        let record: DoseRecord?
        let plan: MedicationPlan

        var status: SlotStatus {
            guard let r = record else { return time < .now ? .missed : .upcoming }
            return r.status == .taken ? .taken : .skipped
        }
    }

    private struct DayGroup: Identifiable {
        let id: Date
        let slots: [SlotEntry]
    }

    private enum TodayItem: Identifiable {
        case slot(SlotEntry)
        case banner(MedicationPlan)

        var id: String {
            switch self {
            case .slot(let e): return e.id.uuidString
            case .banner(let p): return "today-banner-\(p.id)"
            }
        }
    }

    private enum UpcomingItem: Identifiable {
        case dayGroup(DayGroup)
        case banner(MedicationPlan)

        var id: String {
            switch self {
            case .dayGroup(let g): return g.id.ISO8601Format()
            case .banner(let p): return "upcoming-banner-\(p.id)"
            }
        }
    }

    private enum SlotStatus {
        case taken, skipped, missed, upcoming

        var label: String {
            switch self {
            case .taken: return String(localized: "Taken")
            case .skipped: return String(localized: "Skipped")
            case .missed: return String(localized: "Missed")
            case .upcoming: return String(localized: "Upcoming")
            }
        }

        var icon: String {
            switch self {
            case .taken: return "checkmark.circle.fill"
            case .skipped: return "forward.circle.fill"
            case .missed: return "xmark.circle.fill"
            case .upcoming: return "clock.circle"
            }
        }

        var color: Color {
            switch self {
            case .taken: return .green
            case .skipped: return .secondary
            case .missed: return .red
            case .upcoming: return .blue
            }
        }
    }

    // MARK: - Data

    private var allPlans: [MedicationPlan] {
        baby.plans
            .filter { $0.medicationName.localizedCaseInsensitiveCompare(medicationName) == .orderedSame }
            .filter { $0.stoppedDate == nil }
            .sorted { $0.startDate < $1.startDate }
    }

    private var displayPlan: MedicationPlan? {
        allPlans.first(where: { $0.startDate <= .now }) ?? allPlans.first
    }

    // All slots for today from every relevant plan, with banners at plan transitions.
    private var todayItems: [TodayItem] {
        let sorted = allPlans.flatMap { plan in
            DoseScheduler.scheduledTimes(for: plan, on: .now)
                .map { (time: $0, plan: plan) }
        }
        .sorted { $0.time < $1.time }

        var items: [TodayItem] = []
        var lastPlanID: String? = nil

        for (time, plan) in sorted {
            if let id = lastPlanID, id != plan.id {
                items.append(.banner(plan))
            }
            let entry = SlotEntry(time: time, record: DoseScheduler.record(for: time, in: plan), plan: plan)
            items.append(.slot(entry))
            lastPlanID = plan.id
        }

        return items
    }

    // Tomorrow→+7 days: day groups from all plans, with a banner whenever a new
    // future-starting plan takes over from the current one.
    private var upcomingItems: [UpcomingItem] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let lookahead = calendar.date(byAdding: .day, value: 7, to: today)!

        struct Entry {
            let day: Date
            let plan: MedicationPlan
            let slots: [Date]
        }

        var entries: [Entry] = []
        var day = tomorrow
        while day <= lookahead {
            for plan in allPlans {
                let slots = DoseScheduler.scheduledTimes(for: plan, on: day, calendar: calendar)
                if !slots.isEmpty {
                    entries.append(Entry(day: day, plan: plan, slots: slots))
                }
            }
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }

        entries.sort { a, b in
            a.day != b.day ? a.day < b.day : (a.slots.first ?? .distantFuture) < (b.slots.first ?? .distantFuture)
        }

        var items: [UpcomingItem] = []
        var lastPlanID: String? = nil

        for entry in entries {
            let pid = entry.plan.id
            // Insert a banner when transitioning to a plan that starts in the future
            // (plans that started today or earlier are shown without a banner — their
            // transition is already visible in the Today section).
            if pid != lastPlanID && entry.plan.startDate >= tomorrow {
                items.append(.banner(entry.plan))
            }
            let slots = entry.slots.map { time in
                SlotEntry(time: time, record: DoseScheduler.record(for: time, in: entry.plan), plan: entry.plan)
            }
            items.append(.dayGroup(DayGroup(id: entry.day, slots: slots)))
            lastPlanID = pid
        }

        return items
    }

    private var historyGroups: [DayGroup] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        var groups: [DayGroup] = []
        for plan in allPlans {
            let start = calendar.startOfDay(for: plan.startDate)
            var day = yesterday
            while day >= start {
                let slots = DoseScheduler.scheduledTimes(for: plan, on: day, calendar: calendar)
                if !slots.isEmpty {
                    groups.append(DayGroup(
                        id: day,
                        slots: slots.map { SlotEntry(time: $0, record: DoseScheduler.record(for: $0, in: plan), plan: plan) }
                    ))
                }
                day = calendar.date(byAdding: .day, value: -1, to: day)!
            }
        }

        return groups.sorted { $0.id > $1.id }
    }

    // MARK: - Subviews

    private struct ScheduleChangeBanner: View {
        let plan: MedicationPlan

        private var label: String {
            let cal = Calendar.current
            if cal.isDateInToday(plan.startDate) {
                return String(localized: "Schedule changes at \(plan.startDate.formatted(date: .omitted, time: .shortened))")
            } else if cal.isDateInTomorrow(plan.startDate) {
                return String(localized: "Schedule changes tomorrow")
            } else {
                return String(localized: "Schedule changes on \(plan.startDate.formatted(date: .abbreviated, time: .omitted))")
            }
        }

        var body: some View {
            HStack(spacing: 12) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.subheadline.bold())
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.subheadline.bold())
                    Text("\(plan.doseSummary) · \(plan.frequencySummary)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
            .listRowBackground(Color.blue.opacity(0.08))
        }
    }

    private struct ReadOnlySlotRow: View {
        let entry: SlotEntry
        var body: some View {
            HStack {
                Image(systemName: entry.status.icon).foregroundStyle(entry.status.color)
                Text(entry.time, style: .time).font(.subheadline)
                Spacer()
                Text(entry.status.label).font(.caption).foregroundStyle(entry.status.color)
            }
        }
    }

    // Extracted into a struct to avoid ChartContentBuilder ambiguity in Xcode 16.
    private struct DaySection: View {
        let group: DayGroup
        var body: some View {
            Section(group.id.formatted(date: .complete, time: .omitted)) {
                ForEach(group.slots) { entry in
                    ReadOnlySlotRow(entry: entry)
                }
            }
        }
    }

    private struct UpcomingBannerSection: View {
        let plan: MedicationPlan
        var body: some View {
            Section { ScheduleChangeBanner(plan: plan) }
        }
    }

    // MARK: - Body

    var body: some View {
        List {
            if let plan = displayPlan {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(plan.doseSummary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(plan.frequencySummary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if let end = plan.endDate {
                            Text("Ends \(end.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if !todayItems.isEmpty {
                Section("Today") {
                    ForEach(todayItems) { item in
                        switch item {
                        case .slot(let entry):
                            DoseRowView(slot: entry.time, plan: entry.plan)
                        case .banner(let plan):
                            ScheduleChangeBanner(plan: plan)
                        }
                    }
                }
            }

            if !upcomingItems.isEmpty {
                Section("Upcoming") {}
                ForEach(upcomingItems) { item in
                    switch item {
                    case .dayGroup(let group):
                        DaySection(group: group)
                    case .banner(let plan):
                        UpcomingBannerSection(plan: plan)
                    }
                }
            }

            Section("History") {}
            ForEach(historyGroups) { group in
                DaySection(group: group)
            }
        }
        .navigationTitle(medicationName)
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    let container = previewContainer
    let baby = try! container.mainContext.fetch(FetchDescriptor<Baby>()).first!
    return NavigationStack {
        MedicationTimelineView(baby: baby, medicationName: "Ibuprofen")
    }
    .modelContainer(container)
}
