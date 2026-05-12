import SwiftUI
import SwiftData

struct HistoryView: View {
    let plan: MedicationPlan

    private struct DayGroup: Identifiable {
        let id: Date
        let slots: [SlotEntry]
    }

    private struct SlotEntry: Identifiable {
        let id = UUID()
        let time: Date
        let record: DoseRecord?

        var status: SlotStatus {
            guard let r = record else {
                return time < .now ? .missed : .upcoming
            }
            return r.status == .taken ? .taken : .skipped
        }
    }

    private enum SlotStatus {
        case taken, skipped, missed, upcoming

        var label: String {
            switch self {
            case .taken: return "Taken"
            case .skipped: return "Skipped"
            case .missed: return "Missed"
            case .upcoming: return "Upcoming"
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

    private var upcomingGroups: [DayGroup] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let lookahead = calendar.date(byAdding: .day, value: 7, to: today)!
        let end = plan.endDate.map { min(calendar.startOfDay(for: $0), lookahead) } ?? lookahead

        var groups: [DayGroup] = []
        var day = tomorrow
        while day <= end {
            let slots = DoseScheduler.scheduledTimes(for: plan, on: day, calendar: calendar)
            if !slots.isEmpty {
                groups.append(DayGroup(id: day, slots: slots.map {
                    SlotEntry(time: $0, record: DoseScheduler.record(for: $0, in: plan))
                }))
            }
            day = calendar.date(byAdding: .day, value: 1, to: day) ?? day.addingTimeInterval(86401)
        }
        return groups
    }

    private var todaySlots: [SlotEntry] {
        DoseScheduler.scheduledTimes(for: plan, on: .now)
            .map { SlotEntry(time: $0, record: DoseScheduler.record(for: $0, in: plan)) }
    }

    private var historyGroups: [DayGroup] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: plan.startDate)
        let today = calendar.startOfDay(for: .now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        var groups: [DayGroup] = []
        var day = yesterday
        while day >= start {
            let slots = DoseScheduler.scheduledTimes(for: plan, on: day, calendar: calendar)
            if !slots.isEmpty {
                groups.append(DayGroup(id: day, slots: slots.map {
                    SlotEntry(time: $0, record: DoseScheduler.record(for: $0, in: plan))
                }))
            }
            day = calendar.date(byAdding: .day, value: -1, to: day) ?? start.addingTimeInterval(-1)
        }
        return groups
    }

    @ViewBuilder
    private func doseRow(_ entry: SlotEntry) -> some View {
        HStack {
            Image(systemName: entry.status.icon)
                .foregroundStyle(entry.status.color)
            Text(entry.time, style: .time)
                .font(.subheadline)
            Spacer()
            Text(entry.status.label)
                .font(.caption)
                .foregroundStyle(entry.status.color)
        }
    }

    var body: some View {
        List {
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

            if !todaySlots.isEmpty {
                Section("Today") {
                    ForEach(todaySlots) { entry in
                        DoseRowView(slot: entry.time, plan: plan)
                    }
                }
            }

            if !upcomingGroups.isEmpty {
                Section("Upcoming") {}
                ForEach(upcomingGroups) { group in
                    Section(group.id.formatted(date: .complete, time: .omitted)) {
                        ForEach(group.slots) { entry in
                            doseRow(entry)
                        }
                    }
                }
            }

            Section("History") {}
            ForEach(historyGroups) { group in
                Section(group.id.formatted(date: .complete, time: .omitted)) {
                    ForEach(group.slots) { entry in
                        doseRow(entry)
                    }
                }
            }
        }
        .navigationTitle(plan.medicationName)
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    let container = previewContainer
    let plan = try! container.mainContext.fetch(FetchDescriptor<MedicationPlan>()).first!
    return NavigationStack {
        HistoryView(plan: plan)
    }
    .modelContainer(container)
}
