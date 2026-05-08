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
    @State private var showDuplicateAlert = false
    @State private var doseAmount: String = "5"
    @State private var doseUnit: String = "ml"
    @State private var customUnit: String = ""
    @State private var frequencyUnit: FrequencyUnit = .everyNHours
    @State private var frequencyValue: Int = 8
    @State private var selectedWeekdays: Set<Int> = []
    @State private var startDate: Date = .now
    @State private var hasEndDate: Bool = false
    @State private var endDate: Date = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
    @State private var notes: String = ""

    private var isEditing: Bool { plan != nil }
    private var effectiveDoseUnit: String { doseUnit == "Custom" ? customUnit : doseUnit }

    private var stepperLabel: String {
        switch frequencyUnit {
        case .everyNHours: return "Every \(frequencyValue) hours"
        case .timesPerDay, .specificDays: return "\(frequencyValue) times per day"
        case .everyNDays: return frequencyValue == 1 ? "Every day" : "Every \(frequencyValue) days"
        }
    }

    private var stepperRange: ClosedRange<Int> {
        switch frequencyUnit {
        case .everyNHours: return 1...24
        case .timesPerDay, .specificDays: return 1...12
        case .everyNDays: return 1...30
        }
    }

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
                    .onChange(of: frequencyUnit) { _, newUnit in
                        switch newUnit {
                        case .everyNHours:  frequencyValue = min(frequencyValue, 24)
                        case .timesPerDay, .specificDays: frequencyValue = min(max(frequencyValue, 1), 12)
                        case .everyNDays:   frequencyValue = min(max(frequencyValue, 1), 30)
                        }
                    }

                    if frequencyUnit == .specificDays {
                        WeekdayPicker(selectedWeekdays: $selectedWeekdays)
                    }

                    Stepper(stepperLabel, value: $frequencyValue, in: stepperRange)

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
            .alert("Already Scheduled", isPresented: $showDuplicateAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("\(medicationName.trimmingCharacters(in: .whitespaces)) already has an active schedule. End the current schedule before adding a new one.")
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
            && (frequencyUnit != .specificDays || !selectedWeekdays.isEmpty)
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
        selectedWeekdays = Set(p.weekdays)
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
        selectedWeekdays = Set(p.weekdays)
        startDate = p.startDate
        if let end = p.endDate {
            hasEndDate = true
            endDate = end
        }
        notes = p.notes
    }

    private func save() {
        let trimmedName = medicationName.trimmingCharacters(in: .whitespaces)
        if plan == nil {
            let isDuplicate = baby.plans.contains {
                $0.medicationName.localizedCaseInsensitiveCompare(trimmedName) == .orderedSame && $0.isActive
            }
            if isDuplicate {
                showDuplicateAlert = true
                return
            }
        }
        let amount = Double(doseAmount) ?? 0
        if let p = plan {
            p.medicationName = trimmedName
            p.doseAmount = amount
            p.doseUnit = effectiveDoseUnit
            p.frequencyUnit = frequencyUnit
            p.frequencyValue = frequencyValue
            p.weekdays = Array(selectedWeekdays)
            p.startDate = startDate
            p.endDate = hasEndDate ? endDate : nil
            p.notes = notes
            NotificationManager.shared.scheduleNotifications(for: p)
            Task { await FirestoreService.shared.save(p) }
        } else {
            let p = MedicationPlan(
                medicationName: trimmedName,
                doseAmount: amount,
                doseUnit: effectiveDoseUnit,
                frequencyUnit: frequencyUnit,
                frequencyValue: frequencyValue,
                startDate: startDate,
                endDate: hasEndDate ? endDate : nil,
                notes: notes
            )
            p.weekdays = Array(selectedWeekdays)
            p.baby = baby
            modelContext.insert(p)
            NotificationManager.shared.scheduleNotifications(for: p)
            Task { await FirestoreService.shared.save(p) }
        }
        dismiss()
    }
}

private struct WeekdayPicker: View {
    @Binding var selectedWeekdays: Set<Int>

    private var orderedWeekdays: [(Int, String)] {
        let cal = Calendar.current
        let symbols = cal.shortWeekdaySymbols
        let first = cal.firstWeekday
        return (0..<7).map { offset in
            let index = (first - 1 + offset) % 7
            return (index + 1, symbols[index])
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(orderedWeekdays, id: \.0) { (weekday, label) in
                let selected = selectedWeekdays.contains(weekday)
                Button {
                    if selected { selectedWeekdays.remove(weekday) }
                    else { selectedWeekdays.insert(weekday) }
                } label: {
                    Text(label)
                        .font(.caption)
                        .fontWeight(selected ? .semibold : .regular)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(selected ? Color.accentColor : Color(.systemGray5))
                        .foregroundStyle(selected ? .white : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    let container = previewContainer
    let baby = try! container.mainContext.fetch(FetchDescriptor<Baby>()).first!
    return PlanFormView(baby: baby)
        .modelContainer(container)
}
