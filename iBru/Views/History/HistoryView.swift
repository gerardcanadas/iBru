import SwiftUI

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

    private var dayGroups: [DayGroup] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: plan.startDate)
        let end = calendar.startOfDay(for: min(.now, plan.endDate ?? .now))

        var groups: [DayGroup] = []
        var day = end
        while day >= start {
            let slots = DoseScheduler.scheduledTimes(for: plan, on: day, calendar: calendar)
            if !slots.isEmpty {
                let entries = slots.map { slot in
                    SlotEntry(time: slot, record: DoseScheduler.record(for: slot, in: plan))
                }
                groups.append(DayGroup(id: day, slots: entries))
            }
            day = calendar.date(byAdding: .day, value: -1, to: day) ?? start.addingTimeInterval(-1)
        }
        return groups
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

            ForEach(dayGroups) { group in
                Section(group.id.formatted(date: .complete, time: .omitted)) {
                    ForEach(group.slots) { entry in
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
