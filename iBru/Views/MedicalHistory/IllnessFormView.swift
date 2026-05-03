import SwiftUI
import SwiftData

private struct PlanOption: Identifiable {
    let id: PersistentIdentifier
    let name: String
    let dose: String
    let frequency: String
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

    private var isEditing: Bool { illness != nil }

    private var planOptions: [PlanOption] {
        baby.plans
            .sorted { $0.medicationName < $1.medicationName }
            .map { PlanOption(id: $0.persistentModelID, name: $0.medicationName, dose: $0.doseSummary, frequency: $0.frequencySummary) }
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

                Section("Medications taken") {
                    if planOptions.isEmpty {
                        Text("No medication plans recorded")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(planOptions) { option in
                            Button {
                                if selectedPlanIDs.contains(option.id) {
                                    selectedPlanIDs.remove(option.id)
                                } else {
                                    selectedPlanIDs.insert(option.id)
                                }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(option.name)
                                            .foregroundStyle(.primary)
                                        Text("\(option.dose) · \(option.frequency)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if selectedPlanIDs.contains(option.id) {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.tint)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
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

        if let r = illness {
            r.title = trimmed
            r.startDate = startDate
            r.endDate = hasEndDate ? endDate : nil
            r.notes = notes
            r.plans = linkedPlans
        } else {
            let r = IllnessRecord(
                title: trimmed,
                startDate: startDate,
                endDate: hasEndDate ? endDate : nil,
                notes: notes
            )
            r.baby = baby
            r.plans = linkedPlans
            modelContext.insert(r)
        }
        dismiss()
    }
}
