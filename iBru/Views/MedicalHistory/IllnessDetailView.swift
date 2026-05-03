import SwiftUI
import SwiftData

struct IllnessDetailView: View {
    let record: IllnessRecord

    private struct PlanSummary: Identifiable {
        let id: PersistentIdentifier
        let name: String
        let detail: String
    }

    private var planSummaries: [PlanSummary] {
        record.plans
            .sorted { $0.medicationName < $1.medicationName }
            .map { PlanSummary(id: $0.persistentModelID, name: $0.medicationName, detail: "\($0.doseSummary) · \($0.frequencySummary)") }
    }

    private var durationText: String {
        guard let end = record.endDate else { return "Ongoing" }
        let days = Calendar.current.dateComponents([.day], from: record.startDate, to: end).day ?? 0
        return days == 1 ? "1 day" : "\(days) days"
    }

    var body: some View {
        List {
            Section {
                LabeledContent("Status") {
                    Text(record.isOngoing ? "Ongoing" : "Recovered")
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(record.isOngoing ? Color.orange.opacity(0.15) : Color.green.opacity(0.15))
                        .foregroundStyle(record.isOngoing ? .orange : .green)
                        .clipShape(Capsule())
                }
                LabeledContent("Started", value: record.startDate.formatted(date: .abbreviated, time: .omitted))
                if let end = record.endDate {
                    LabeledContent("Recovered", value: end.formatted(date: .abbreviated, time: .omitted))
                }
                LabeledContent("Duration", value: durationText)
            }

            if !planSummaries.isEmpty {
                Section("Medications taken") {
                    ForEach(planSummaries) { plan in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(plan.name)
                            Text(plan.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            if !record.notes.isEmpty {
                Section("Notes") {
                    Text(record.notes)
                        .foregroundStyle(.secondary)
                }
            }

            if record.isOngoing {
                Section {
                    Button {
                        record.endDate = Calendar.current.startOfDay(for: .now)
                    } label: {
                        Label("Mark as Recovered", systemImage: "checkmark.circle")
                            .foregroundStyle(.orange)
                    }
                } footer: {
                    Text("Sets today as the recovery date and moves this record to Past.")
                }
            }
        }
        .navigationTitle(record.title)
        .navigationBarTitleDisplayMode(.large)
    }
}
