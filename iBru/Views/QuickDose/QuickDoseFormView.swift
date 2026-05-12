import SwiftUI
import SwiftData

struct QuickDoseFormView: View {
    let baby: Baby

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPlanID: PersistentIdentifier?
    @State private var medicationName = ""
    @State private var doseAmountText = ""
    @State private var doseUnit = "ml"
    @State private var givenAt = Date.now
    @State private var notes = ""
    @State private var showingIntervalWarning = false
    @State private var intervalWarningMessage = ""

    // MARK: - Plan options (wrapper avoids ForEach @Model-in-Form compiler issue)

    private struct PlanOption: Identifiable {
        let id: PersistentIdentifier
        let name: String
        let doseSummary: String
        let doseAmount: Double
        let doseUnit: String
        let plan: MedicationPlan
    }

    private var planOptions: [PlanOption] {
        var seen = Set<String>()
        var options: [PlanOption] = []
        let sorted = baby.plans.sorted { a, b in
            if a.isActive != b.isActive { return a.isActive }
            return a.medicationName < b.medicationName
        }
        for plan in sorted where !seen.contains(plan.medicationName) {
            seen.insert(plan.medicationName)
            options.append(PlanOption(
                id: plan.persistentModelID,
                name: plan.medicationName,
                doseSummary: plan.doseSummary,
                doseAmount: plan.doseAmount,
                doseUnit: plan.doseUnit,
                plan: plan
            ))
        }
        return options.sorted { $0.name < $1.name }
    }

    private var isValid: Bool {
        selectedPlanID != nil && !doseAmountText.isEmpty && Double(doseAmountText) != nil
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                Section("Medication") {
                    ForEach(planOptions) { option in
                        Button { selectPlan(option) } label: {
                            planRow(option)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if selectedPlanID != nil {
                    Section("Dose") {
                        HStack {
                            TextField("Amount", text: $doseAmountText)
                                .keyboardType(.decimalPad)
                            Divider()
                            TextField("Unit", text: $doseUnit)
                                .frame(width: 48)
                                .multilineTextAlignment(.center)
                        }
                    }

                    Section {
                        DatePicker("Time", selection: $givenAt, displayedComponents: .hourAndMinute)
                        TextField("Notes (optional)", text: $notes, axis: .vertical)
                            .lineLimit(2...4)
                    }
                }
            }
            .navigationTitle("Quick Dose")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Log") { attemptSave() }
                        .disabled(!isValid)
                }
            }
            .confirmationDialog(
                "Given recently",
                isPresented: $showingIntervalWarning,
                titleVisibility: .visible
            ) {
                Button("Log anyway") { save() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(intervalWarningMessage)
            }
        }
    }

    // MARK: - Sub-views

    @ViewBuilder
    private func planRow(_ option: PlanOption) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(option.name).foregroundStyle(.primary)
                Text(option.doseSummary).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if selectedPlanID == option.id {
                Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
            }
        }
    }

    // MARK: - Actions

    private func selectPlan(_ option: PlanOption) {
        selectedPlanID = option.id
        medicationName = option.name
        doseAmountText = option.doseAmount.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(option.doseAmount))
            : String(format: "%.1f", option.doseAmount)
        doseUnit = option.doseUnit
    }

    private func attemptSave() {
        if let warning = intervalWarning() {
            intervalWarningMessage = warning
            showingIntervalWarning = true
        } else {
            save()
        }
    }

    private func intervalWarning() -> String? {
        guard let option = planOptions.first(where: { $0.id == selectedPlanID }) else { return nil }
        let plan = option.plan

        let minIntervalHours: Double
        switch plan.frequencyUnit {
        case .everyNHours:
            minIntervalHours = Double(plan.frequencyValue)
        case .timesPerDay:
            minIntervalHours = 24.0 / Double(plan.frequencyValue)
        default:
            return nil
        }

        let doseRecords = (try? modelContext.fetch(FetchDescriptor<DoseRecord>())) ?? []
        let lastScheduled = doseRecords
            .filter { $0.plan?.medicationName == medicationName && $0.status == .taken }
            .map { $0.recordedDate }
            .max()

        let quickRecords = (try? modelContext.fetch(FetchDescriptor<QuickDoseRecord>())) ?? []
        let lastQuick = quickRecords
            .filter { $0.medicationName == medicationName && $0.baby?.id == baby.id }
            .map { $0.givenAt }
            .max()

        let lastGiven: Date?
        if let s = lastScheduled, let q = lastQuick { lastGiven = max(s, q) }
        else { lastGiven = lastScheduled ?? lastQuick }

        guard let lastGiven else { return nil }

        let hoursElapsed = givenAt.timeIntervalSince(lastGiven) / 3600
        guard hoursElapsed >= 0, hoursElapsed < minIntervalHours else { return nil }

        let h = Int(hoursElapsed)
        let m = Int((hoursElapsed - Double(h)) * 60)
        let timeStr = h > 0 ? "\(h)h \(m)m ago" : "\(m)m ago"
        return "\(medicationName) was last given \(timeStr). The usual interval is \(Int(minIntervalHours))h."
    }

    private func save() {
        guard let amount = Double(doseAmountText) else { return }
        let r = QuickDoseRecord(
            medicationName: medicationName,
            doseAmount: amount,
            doseUnit: doseUnit,
            givenAt: givenAt,
            notes: notes
        )
        r.baby = baby
        modelContext.insert(r)
        Task { await FirestoreService.shared.save(r) }
        dismiss()
    }
}
