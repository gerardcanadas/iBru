import SwiftUI
import SwiftData

struct VaccineFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var baby: Baby
    var vaccine: VaccineRecord?

    @State private var name: String = ""
    @State private var recommendedAgeDays: Int = 60
    @State private var hasGivenDate: Bool = false
    @State private var givenDate: Date = .now
    @State private var notes: String = ""

    private var isEditing: Bool { vaccine != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Vaccine") {
                    TextField("e.g. MMR, DTaP, Hepatitis B", text: $name)
                }

                Section("Recommended age") {
                    Stepper(recommendedAgeLabel, value: $recommendedAgeDays, in: 0...3650, step: 30)
                }

                Section {
                    Toggle("Given", isOn: $hasGivenDate)
                    if hasGivenDate {
                        DatePicker("Given on", selection: $givenDate, in: ...Date.now, displayedComponents: .date)
                    }
                }

                Section("Notes") {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }
            }
            .navigationTitle(isEditing ? "Edit Vaccine" : "New Vaccine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { loadFromRecord() }
        }
    }

    private var recommendedAgeLabel: String {
        if recommendedAgeDays == 0 { return String(localized: "At birth") }
        let months = recommendedAgeDays / 30
        if months >= 2 { return String(localized: "\(months) months") }
        let weeks = recommendedAgeDays / 7
        if weeks >= 1 { return String(localized: "\(weeks) weeks") }
        return String(localized: "\(recommendedAgeDays) days")
    }

    private func loadFromRecord() {
        guard let v = vaccine else { return }
        name = v.name
        recommendedAgeDays = v.recommendedAgeDays
        if let given = v.givenDate {
            hasGivenDate = true
            givenDate = given
        }
        notes = v.notes
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if let v = vaccine {
            v.name = trimmed
            v.recommendedAgeDays = recommendedAgeDays
            v.givenDate = hasGivenDate ? givenDate : nil
            v.notes = notes
            Task { await FirestoreService.shared.save(v) }
        } else {
            let v = VaccineRecord(
                name: trimmed,
                recommendedAgeDays: recommendedAgeDays,
                givenDate: hasGivenDate ? givenDate : nil,
                notes: notes
            )
            v.baby = baby
            modelContext.insert(v)
            Task { await FirestoreService.shared.save(v) }
        }
        dismiss()
    }
}
