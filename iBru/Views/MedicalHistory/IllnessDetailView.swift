import SwiftUI
import SwiftData

struct IllnessDetailView: View {
    let record: IllnessRecord
    @State private var showingEdit = false

    private struct DoseEntry: Identifiable {
        let id: UUID = UUID()
        let scheduledDate: Date
        let status: DoseStatus
    }

    private struct PlanSummary: Identifiable {
        let id: PersistentIdentifier
        let name: String
        let detail: String
        let doses: [DoseEntry]

        var takenCount: Int { doses.filter { $0.status == .taken }.count }
        var skippedCount: Int { doses.filter { $0.status == .skipped }.count }
    }

    private var planSummaries: [PlanSummary] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: record.startDate)
        let end: Date = {
            guard let endDate = record.endDate else { return Date.now }
            return cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: endDate)) ?? endDate
        }()
        return record.plans
            .sorted { $0.medicationName < $1.medicationName }
            .map { plan in
                let doses = plan.records
                    .filter { $0.scheduledDate >= start && $0.scheduledDate < end }
                    .sorted { $0.scheduledDate < $1.scheduledDate }
                    .map { DoseEntry(scheduledDate: $0.scheduledDate, status: $0.status) }
                return PlanSummary(
                    id: plan.persistentModelID,
                    name: plan.medicationName,
                    detail: "\(plan.doseSummary) · \(plan.frequencySummary)",
                    doses: doses
                )
            }
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

            if planSummaries.isEmpty {
                Section("Medications") {
                    Text("No medications linked to this record. Tap Edit to add them.")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
            } else {
                ForEach(planSummaries) { plan in
                    Section {
                        if plan.doses.isEmpty {
                            Text("No doses logged during this illness")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(plan.doses) { dose in
                                HStack(spacing: 10) {
                                    Image(systemName: dose.status == .taken ? "checkmark.circle.fill" : "forward.fill")
                                        .foregroundStyle(dose.status == .taken ? .green : .orange)
                                        .font(.subheadline)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(dose.scheduledDate, style: .date)
                                            .font(.subheadline)
                                        Text(dose.scheduledDate, style: .time)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(dose.status == .taken ? "Taken" : "Skipped")
                                        .font(.caption)
                                        .foregroundStyle(dose.status == .taken ? .green : .orange)
                                }
                            }
                        }
                    } header: {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(plan.name)
                            Text(plan.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textCase(nil)
                            if !plan.doses.isEmpty {
                                Text("\(plan.takenCount) taken · \(plan.skippedCount) skipped")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .textCase(nil)
                            }
                        }
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
                        for plan in record.plans where plan.isActive {
                            plan.stoppedDate = .now
                            NotificationManager.shared.cancelAllNotifications(for: plan)
                            Task { await FirestoreService.shared.save(plan) }
                        }
                        Task { await FirestoreService.shared.save(record) }
                    } label: {
                        Label("Mark as Recovered", systemImage: "checkmark.circle")
                            .foregroundStyle(.orange)
                    }
                } footer: {
                    Text("Sets today as the recovery date and stops any linked medication schedules.")
                }
            } else {
                Section {
                    Button {
                        record.endDate = nil
                        for plan in record.plans where plan.stoppedDate != nil {
                            plan.stoppedDate = nil
                            NotificationManager.shared.scheduleNotifications(for: plan)
                            Task { await FirestoreService.shared.save(plan) }
                        }
                        Task { await FirestoreService.shared.save(record) }
                    } label: {
                        Label("Reopen", systemImage: "arrow.uturn.backward.circle")
                            .foregroundStyle(.blue)
                    }
                } footer: {
                    Text("Removes the recovery date and reactivates linked medication schedules.")
                }
            }
        }
        .navigationTitle(record.title)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { showingEdit = true }
            }
        }
        .sheet(isPresented: $showingEdit) {
            IllnessFormView(baby: record.baby!, illness: record)
        }
    }
}
