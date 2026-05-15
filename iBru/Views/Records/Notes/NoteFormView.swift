import SwiftUI
import SwiftData

struct NoteFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let illness: IllnessRecord
    var note: DailyNote?

    @State private var date: Date = .now
    @State private var content: String = ""

    private var isEditing: Bool { note != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }
                Section("Observations") {
                    TextEditor(text: $content)
                        .frame(minHeight: 160)
                }
            }
            .navigationTitle(isEditing ? "Edit Note" : "New Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                if let n = note {
                    date = n.date
                    content = n.content
                }
            }
        }
    }

    private func save() {
        let day = Calendar.current.startOfDay(for: date)
        if let n = note {
            n.date = day
            n.content = content
            Task { await FirestoreService.shared.save(n) }
        } else {
            let n = DailyNote(date: day, content: content)
            modelContext.insert(n)
            illness.dailyNotes.append(n)
            Task { await FirestoreService.shared.save(n) }
        }
        dismiss()
    }
}

#Preview {
    let container = previewContainer
    let illness = try! container.mainContext.fetch(FetchDescriptor<IllnessRecord>()).first!
    NoteFormView(illness: illness)
        .modelContainer(container)
}
