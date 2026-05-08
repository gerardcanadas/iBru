import SwiftUI
import SwiftData

private let colorOptions: [(String, String)] = [
    ("Blue", "#5B8DEF"),
    ("Pink", "#F472B6"),
    ("Purple", "#A78BFA"),
    ("Green", "#34D399"),
    ("Orange", "#FB923C"),
    ("Red", "#F87171"),
    ("Yellow", "#FBBF24"),
    ("Teal", "#2DD4BF"),
]

struct BabyFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var baby: Baby?

    @State private var name: String = ""
    @State private var birthDate: Date = Calendar.current.date(byAdding: .month, value: -3, to: .now) ?? .now
    @State private var colorHex: String = "#5B8DEF"

    var isEditing: Bool { baby != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Baby info") {
                    TextField("Name", text: $name)
                    DatePicker("Birth date", selection: $birthDate, in: ...Date.now, displayedComponents: .date)
                }

                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                        ForEach(colorOptions, id: \.0) { label, hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Circle().stroke(colorHex == hex ? Color.primary : Color.clear, lineWidth: 3)
                                )
                                .onTapGesture { colorHex = hex }
                                .accessibilityLabel(label)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(isEditing ? "Edit Profile" : "New Baby")
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
            .onAppear {
                if let b = baby {
                    name = b.name
                    birthDate = b.birthDate
                    colorHex = b.colorHex
                }
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if let b = baby {
            b.name = trimmed
            b.birthDate = birthDate
            b.colorHex = colorHex
            Task { await FirestoreService.shared.save(b) }
        } else {
            let b = Baby(name: trimmed, birthDate: birthDate, colorHex: colorHex)
            modelContext.insert(b)
            Task { await FirestoreService.shared.save(b) }
        }
        dismiss()
    }
}

#Preview {
    BabyFormView()
        .modelContainer(previewContainer)
}
