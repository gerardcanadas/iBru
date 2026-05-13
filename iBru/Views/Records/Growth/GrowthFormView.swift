import SwiftUI
import SwiftData

struct GrowthFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var baby: Baby
    var record: GrowthRecord?

    @State private var date: Date = .now
    @State private var weightText: String = ""
    @State private var heightText: String = ""
    @State private var headText: String = ""
    @State private var notes: String = ""

    private var isEditing: Bool { record != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Date") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }

                Section("Measurements") {
                    HStack {
                        Text("Weight")
                        Spacer()
                        TextField("e.g. 6.5", text: $weightText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 100)
                        Text("kg").foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Height")
                        Spacer()
                        TextField("e.g. 65.0", text: $heightText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 100)
                        Text("cm").foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Head circumference")
                        Spacer()
                        TextField("e.g. 42.0", text: $headText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 100)
                        Text("cm").foregroundStyle(.secondary)
                    }
                }

                Section("Notes") {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }
            }
            .navigationTitle(isEditing ? "Edit Measurement" : "Log Measurement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!hasAnyMeasurement)
                }
            }
            .onAppear { loadFromRecord() }
        }
    }

    private var hasAnyMeasurement: Bool {
        parsed(weightText) != nil || parsed(heightText) != nil || parsed(headText) != nil
    }

    private func parsed(_ text: String) -> Double? {
        let cleaned = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard !cleaned.isEmpty else { return nil }
        return Double(cleaned)
    }

    private func loadFromRecord() {
        guard let r = record else { return }
        date = r.date
        if let w = r.weightKg { weightText = String(format: "%.2f", w) }
        if let h = r.heightCm { heightText = String(format: "%.1f", h) }
        if let hc = r.headCircumferenceCm { headText = String(format: "%.1f", hc) }
        notes = r.notes
    }

    private func save() {
        if let r = record {
            r.date = date
            r.weightKg = parsed(weightText)
            r.heightCm = parsed(heightText)
            r.headCircumferenceCm = parsed(headText)
            r.notes = notes
            Task { await FirestoreService.shared.save(r) }
        } else {
            let r = GrowthRecord(
                date: date,
                weightKg: parsed(weightText),
                heightCm: parsed(heightText),
                headCircumferenceCm: parsed(headText),
                notes: notes
            )
            r.baby = baby
            modelContext.insert(r)
            Task { await FirestoreService.shared.save(r) }
        }
        dismiss()
    }
}
