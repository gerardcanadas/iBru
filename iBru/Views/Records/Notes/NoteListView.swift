import SwiftUI
import SwiftData

struct NoteListView: View {
    @Environment(\.modelContext) private var modelContext
    let baby: Baby

    @Query(sort: \DailyNote.date, order: .reverse) private var allNotes: [DailyNote]
    @State private var editingNote: DailyNote?

    private var generalNotes: [DailyNote] {
        allNotes.filter { $0.baby?.id == baby.id && $0.illness == nil }
    }

    var body: some View {
        Group {
            if generalNotes.isEmpty {
                ContentUnavailableView(
                    "No Notes",
                    systemImage: "note.text",
                    description: Text("General observations will appear here")
                )
            } else {
                List {
                    ForEach(generalNotes) { note in
                        Button { editingNote = note } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(note.date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text(note.content)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)
                            }
                            .padding(.vertical, 2)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) { delete(note) } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Notes")
        .sheet(item: $editingNote) { note in
            NoteFormView(baby: baby, note: note)
        }
    }

    private func delete(_ note: DailyNote) {
        let id = note.id
        modelContext.delete(note)
        Task { await FirestoreService.shared.delete(noteId: id) }
    }
}

#Preview {
    let container = previewContainer
    let baby = try! container.mainContext.fetch(FetchDescriptor<Baby>()).first!
    return NavigationStack {
        NoteListView(baby: baby)
    }
    .modelContainer(container)
}
