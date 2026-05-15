import SwiftUI
import SwiftData

struct NoteListView: View {
    @Environment(\.modelContext) private var modelContext
    let baby: Baby

    @State private var showingAdd = false
    @State private var editingNote: DailyNote?
    @State private var noteToDelete: DailyNote?

    private var sortedNotes: [DailyNote] {
        baby.dailyNotes.sorted { $0.date > $1.date }
    }

    private var noteForToday: DailyNote? {
        baby.dailyNotes.first { Calendar.current.isDateInToday($0.date) }
    }

    var body: some View {
        List {
            if sortedNotes.isEmpty {
                ContentUnavailableView(
                    "No notes yet",
                    systemImage: "note.text",
                    description: Text("Tap + to add observations for today")
                )
            } else {
                ForEach(sortedNotes) { note in
                    Button { editingNote = note } label: {
                        NoteRowView(note: note)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { noteToDelete = note } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        Button { editingNote = note } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    if let existing = noteForToday {
                        editingNote = existing
                    } else {
                        showingAdd = true
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .confirmationDialog(
            "Delete note?",
            isPresented: Binding(get: { noteToDelete != nil }, set: { if !$0 { noteToDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let n = noteToDelete {
                    let id = n.id
                    modelContext.delete(n)
                    Task { await FirestoreService.shared.delete(noteId: id) }
                }
                noteToDelete = nil
            }
            Button("Cancel", role: .cancel) { noteToDelete = nil }
        }
        .sheet(isPresented: $showingAdd) {
            NoteFormView(baby: baby)
        }
        .sheet(item: $editingNote) { n in
            NoteFormView(baby: baby, note: n)
        }
    }
}

private struct NoteRowView: View {
    let note: DailyNote

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(note.date.formatted(date: .complete, time: .omitted))
                .font(.subheadline.weight(.semibold))
            Text(note.content)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 2)
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
