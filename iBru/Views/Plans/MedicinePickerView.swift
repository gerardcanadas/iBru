import SwiftUI
import SwiftData

struct MedicinePickerView: View {
    let plans: [MedicationPlan]
    let onSelect: (MedicationPlan?) -> Void

    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss

    private var uniquePlans: [MedicationPlan] {
        var seen: [String: MedicationPlan] = [:]
        for plan in plans.sorted(by: { $0.startDate > $1.startDate }) {
            let key = plan.medicationName.lowercased()
            if seen[key] == nil { seen[key] = plan }
        }
        return seen.values.sorted {
            $0.medicationName.localizedCaseInsensitiveCompare($1.medicationName) == .orderedAscending
        }
    }

    private var filteredPlans: [MedicationPlan] {
        guard !searchText.isEmpty else { return uniquePlans }
        return uniquePlans.filter { $0.medicationName.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List {
                Button {
                    onSelect(nil)
                    dismiss()
                } label: {
                    Label("New medicine", systemImage: "plus.circle.fill")
                }

                ForEach(filteredPlans) { plan in
                    Button {
                        onSelect(plan)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(plan.medicationName)
                                .foregroundStyle(.primary)
                            Text("\(plan.doseSummary) · \(plan.frequencySummary)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search medicines")
            .navigationTitle("Select Medicine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
