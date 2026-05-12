import SwiftUI
import SwiftData

private struct PlanOption: Identifiable {
    let id: PersistentIdentifier
    let name: String
    let dose: String
    let frequency: String
    let isActive: Bool
}

struct IllnessFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var baby: Baby
    var illness: IllnessRecord?

    @State private var title: String = ""
    @State private var startDate: Date = .now
    @State private var hasEndDate: Bool = false
    @State private var endDate: Date = .now
    @State private var notes: String = ""
    @State private var selectedPlanIDs: Set<PersistentIdentifier> = []
    @State private var showMedicationPicker = false

    private var isEditing: Bool { illness != nil }

    private var planOptions: [PlanOption] {
        baby.plans
            .sorted { $0.medicationName < $1.medicationName }
            .map { PlanOption(id: $0.persistentModelID, name: $0.medicationName,
                              dose: $0.doseSummary, frequency: $0.frequencySummary,
                              isActive: $0.isActive) }
    }

    private var selectedSummary: String {
        let names = planOptions
            .filter { selectedPlanIDs.contains($0.id) }
            .map(\.name)
        if names.isEmpty { return "None" }
        return names.joined(separator: ", ")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Illness") {
                    TextField("e.g. Cold, Fever, Ear infection", text: $title)
                }

                Section("Dates") {
                    DatePicker("Start date", selection: $startDate, displayedComponents: .date)
                    Toggle("Set end date", isOn: $hasEndDate)
                    if hasEndDate {
                        DatePicker("End date", selection: $endDate, in: startDate..., displayedComponents: .date)
                    }
                }

                Section {
                    Button { showMedicationPicker = true } label: {
                        HStack {
                            Text(selectedSummary)
                                .foregroundStyle(selectedPlanIDs.isEmpty ? .secondary : .primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .foregroundStyle(.primary)
                } header: {
                    Text("Medications taken")
                } footer: {
                    if planOptions.isEmpty {
                        Text("No medication plans have been created for \(baby.name). Create a plan first to link it to an illness.")
                    }
                }

                Section("Notes") {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }
            }
            .navigationTitle(isEditing ? "Edit Record" : "New Illness Record")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { loadFromRecord() }
            .sheet(isPresented: $showMedicationPicker) {
                MedicationPickerSheet(plans: planOptions, selectedIDs: $selectedPlanIDs)
            }
        }
    }

    private func loadFromRecord() {
        guard let r = illness else { return }
        title = r.title
        startDate = r.startDate
        if let end = r.endDate {
            hasEndDate = true
            endDate = end
        }
        notes = r.notes
        selectedPlanIDs = Set(r.plans.map(\.persistentModelID))
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        let linkedPlans = baby.plans.filter { selectedPlanIDs.contains($0.persistentModelID) }
        let cal = Calendar.current
        let cleanStart = cal.startOfDay(for: startDate)
        let cleanEnd = hasEndDate ? cal.startOfDay(for: endDate) : nil as Date?

        if let r = illness {
            r.title = trimmed
            r.startDate = cleanStart
            r.endDate = cleanEnd
            r.notes = notes
            r.plans = linkedPlans
            Task { await FirestoreService.shared.save(r) }
        } else {
            let r = IllnessRecord(
                title: trimmed,
                startDate: cleanStart,
                endDate: cleanEnd,
                notes: notes
            )
            r.baby = baby
            r.plans = linkedPlans
            modelContext.insert(r)
            Task { await FirestoreService.shared.save(r) }
        }
        dismiss()
    }
}

// MARK: - Medication picker sheet

private struct MedicationPickerSheet: View {
    let plans: [PlanOption]
    @Binding var selectedIDs: Set<PersistentIdentifier>
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if plans.isEmpty {
                    ContentUnavailableView(
                        "No medications",
                        systemImage: "pills",
                        description: Text("Create a medication plan first.")
                    )
                } else {
                    List {
                        ForEach(plans) { plan in
                            Button {
                                if selectedIDs.contains(plan.id) {
                                    selectedIDs.remove(plan.id)
                                } else {
                                    selectedIDs.insert(plan.id)
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(plan.name)
                                            .foregroundStyle(.primary)
                                        Text("\(plan.dose) · \(plan.frequency)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        if !plan.isActive {
                                            Text("Inactive")
                                                .font(.caption2)
                                                .foregroundStyle(.orange)
                                        }
                                    }
                                    Spacer()
                                    if selectedIDs.contains(plan.id) {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.tint)
                                            .fontWeight(.semibold)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("Select Medications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                if !selectedIDs.isEmpty {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Clear") { selectedIDs.removeAll() }
                    }
                }
            }
        }
    }
}
