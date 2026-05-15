import SwiftUI
import SwiftData

struct IllnessDetailView: View {
    @Bindable var record: IllnessRecord
    @Environment(\.modelContext) private var modelContext
    @State private var showingEdit = false
    @State private var showingAddTemperature = false
    @State private var editingTemperature: TemperatureReading?
    @State private var showingAddNote = false
    @State private var editingNote: DailyNote?

    private var durationText: String {
        guard let end = record.endDate else { return String(localized: "Ongoing") }
        let days = Calendar.current.dateComponents([.day], from: record.startDate, to: end).day ?? 0
        return days == 1 ? String(localized: "1 day") : String(localized: "\(days) days")
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

            Section("Medications") {
                if record.plans.isEmpty {
                    Text("No medications linked to this record. Tap Edit to add them.")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                } else {
                    ForEach(record.plans.sorted { $0.medicationName < $1.medicationName }) { plan in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(plan.medicationName)
                            Text("\(plan.doseSummary) · \(plan.frequencySummary)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Temperature") {
                ForEach(record.temperatures.sorted { $0.date > $1.date }) { temp in
                    Button { editingTemperature = temp } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(temp.displayValue)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.primary)
                                if let label = temp.feverLabel {
                                    Text(label)
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                }
                            }
                            Spacer()
                            Text(temp.date, format: .dateTime.day().month().hour().minute())
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            let id = temp.id
                            modelContext.delete(temp)
                            Task { await FirestoreService.shared.delete(temperatureId: id) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                Button { showingAddTemperature = true } label: {
                    Label("Log Temperature", systemImage: "thermometer")
                }
            }

            Section("Daily Log") {
                ForEach(record.dailyNotes.sorted { $0.date > $1.date }) { note in
                    Button { editingNote = note } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(note.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text(note.content)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                        }
                        .padding(.vertical, 2)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            let id = note.id
                            modelContext.delete(note)
                            Task { await FirestoreService.shared.delete(noteId: id) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                Button { showingAddNote = true } label: {
                    Label("Add Entry", systemImage: "plus.circle")
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
        .sheet(isPresented: $showingAddTemperature) {
            TemperatureFormView(illness: record)
        }
        .sheet(item: $editingTemperature) { temp in
            TemperatureFormView(illness: record, temperature: temp)
        }
        .sheet(isPresented: $showingAddNote) {
            NoteFormView(baby: record.baby!, illness: record)
        }
        .sheet(item: $editingNote) { n in
            NoteFormView(baby: record.baby!, illness: record, note: n)
        }
    }
}
