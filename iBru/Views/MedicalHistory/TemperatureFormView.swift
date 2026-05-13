import SwiftUI
import SwiftData

struct TemperatureFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var illness: IllnessRecord
    var temperature: TemperatureReading?

    @State private var date: Date = .now
    @State private var valueText: String = "37.0"
    @State private var notes: String = ""

    private var isEditing: Bool { temperature != nil }
    private var parsedValue: Double? {
        Double(valueText.replacingOccurrences(of: ",", with: "."))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Date & time") {
                    DatePicker("Date", selection: $date)
                }
                Section("Reading") {
                    HStack {
                        TextField("37.0", text: $valueText)
                            .keyboardType(.decimalPad)
                        Text("°C")
                            .foregroundStyle(.secondary)
                    }
                }
                Section("Notes") {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }
            }
            .navigationTitle(isEditing ? "Edit Temperature" : "Log Temperature")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(parsedValue == nil)
                }
            }
            .onAppear { loadFromRecord() }
        }
    }

    private func loadFromRecord() {
        guard let t = temperature else { return }
        date = t.date
        valueText = String(format: "%.1f", t.valueCelsius)
        notes = t.notes
    }

    private func save() {
        guard let value = parsedValue else { return }
        if let t = temperature {
            t.date = date
            t.valueCelsius = value
            t.notes = notes
            Task { await FirestoreService.shared.save(t) }
        } else {
            let t = TemperatureReading(date: date, valueCelsius: value, notes: notes)
            t.illness = illness
            modelContext.insert(t)
            Task { await FirestoreService.shared.save(t) }
        }
        dismiss()
    }
}
