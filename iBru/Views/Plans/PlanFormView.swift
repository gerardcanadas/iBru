import SwiftUI
import SwiftData

private let doseUnits = ["mg", "ml", "drops", "tablets", "tsp"]

struct PlanFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var baby: Baby
    var plan: MedicationPlan?

    @State private var medicationName: String = ""
    @State private var showMedicinePicker = false
    @State private var isNewMedicine = false
    @State private var doseAmount: String = "5"
    @State private var doseUnit: String = "ml"
    @State private var customUnit: String = ""
    @State private var frequencyUnit: FrequencyUnit = .everyNHours
    @State private var frequencyValue: Int = 8
    @State private var startDate: Date = .now
    @State private var hasEndDate: Bool = false
    @State private var endDate: Date = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
    @State private var notes: String = ""

    private var isEditing: Bool { plan != nil }
    private var effectiveDoseUnit: String { doseUnit == "Custom" ? customUnit : doseUnit }

    var body: some View {
        NavigationStack {
            Form {
                Section("Medication") {
                    if isNewMedicine {
                        TextField("Name (e.g. Paracetamol)", text: $medicationName)
                    } else {
                        Button {
                            showMedicinePicker = true
                        } label: {
                            HStack {
                                Text(medicationName.isEmpty ? "Select medicine" : medicationName)
                                    .foregroundStyle(medicationName.isEmpty ? .secondary : .primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    HStack {
                        TextField("Amount", text: $doseAmount)
                            .keyboardType(.decimalPad)
                            .frame(width: 80)
                        Picker("Unit", selection: $doseUnit) {
                            ForEach(doseUnits + ["Custom"], id: \.self) { Text($0) }
                        }
                        .pickerStyle(.menu)
                    }
                    if doseUnit == "Custom" {
                        TextField("Custom unit", text: $customUnit)
                    }
                }

                Section("Schedule") {
                    Picker("Frequency type", selection: $frequencyUnit) {
                        ForEach(FrequencyUnit.allCases, id: \.self) { Text($0.rawValue) }
                    }

                    Stepper(
                        frequencyUnit == .everyNHours
                            ? "Every \(frequencyValue) hours"
                            : "\(frequencyValue) times per day",
                        value: $frequencyValue,
                        in: frequencyUnit == .everyNHours ? 1...24 : 1...12
                    )

                    DatePicker("Start date", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                }

                Section("End date") {
                    Toggle("Set end date", isOn: $hasEndDate)
                    if hasEndDate {
                        DatePicker("End date", selection: $endDate, in: startDate..., displayedComponents: .date)
                    }
                }

                Section("Notes") {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }
            }
            .navigationTitle(isEditing ? "Edit Medication" : "New Medication")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!isValid)
                }
            }
            .onAppear {
                loadFromPlan()
                if !isEditing && baby.plans.isEmpty {
                    isNewMedicine = true
                }
            }
            .sheet(isPresented: $showMedicinePicker) {
                MedicinePickerView(plans: baby.plans) { selected in
                    if let selected {
                        applyMedicinePlan(selected)
                    } else {
                        medicationName = ""
                        isNewMedicine = true
                    }
                }
            }
        }
    }

    private var isValid: Bool {
        !medicationName.trimmingCharacters(in: .whitespaces).isEmpty
            && Double(doseAmount) != nil
            && (doseUnit != "Custom" || !customUnit.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    private func applyMedicinePlan(_ p: MedicationPlan) {
        medicationName = p.medicationName
        let amount = p.doseAmount
        doseAmount = amount.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(amount))
            : String(format: "%.2f", amount)
        if doseUnits.contains(p.doseUnit) {
            doseUnit = p.doseUnit
            customUnit = ""
        } else {
            doseUnit = "Custom"
            customUnit = p.doseUnit
        }
        frequencyUnit = p.frequencyUnit
        frequencyValue = p.frequencyValue
    }

    private func loadFromPlan() {
        guard let p = plan else { return }
        isNewMedicine = true
        medicationName = p.medicationName
        doseAmount = p.doseAmount.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(p.doseAmount))
            : String(format: "%.2f", p.doseAmount)
        if doseUnits.contains(p.doseUnit) {
            doseUnit = p.doseUnit
        } else {
            doseUnit = "Custom"
            customUnit = p.doseUnit
        }
        frequencyUnit = p.frequencyUnit
        frequencyValue = p.frequencyValue
        startDate = p.startDate
        if let end = p.endDate {
            hasEndDate = true
            endDate = end
        }
        notes = p.notes
    }

    private func save() {
        let amount = Double(doseAmount) ?? 0
        if let p = plan {
            p.medicationName = medicationName.trimmingCharacters(in: .whitespaces)
            p.doseAmount = amount
            p.doseUnit = effectiveDoseUnit
            p.frequencyUnit = frequencyUnit
            p.frequencyValue = frequencyValue
            p.startDate = startDate
            p.endDate = hasEndDate ? endDate : nil
            p.notes = notes
            NotificationManager.shared.scheduleNotifications(for: p)
        } else {
            let p = MedicationPlan(
                medicationName: medicationName.trimmingCharacters(in: .whitespaces),
                doseAmount: amount,
                doseUnit: effectiveDoseUnit,
                frequencyUnit: frequencyUnit,
                frequencyValue: frequencyValue,
                startDate: startDate,
                endDate: hasEndDate ? endDate : nil,
                notes: notes
            )
            p.baby = baby
            modelContext.insert(p)
            NotificationManager.shared.scheduleNotifications(for: p)
        }
        dismiss()
    }
}

#Preview {
    let container = previewContainer
    let baby = try! container.mainContext.fetch(FetchDescriptor<Baby>()).first!
    return PlanFormView(baby: baby)
        .modelContainer(container)
}
