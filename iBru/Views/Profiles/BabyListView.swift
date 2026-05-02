import SwiftUI
import SwiftData

struct BabyListView: View {
    @Query(sort: \Baby.name) private var babies: [Baby]
    @Environment(\.modelContext) private var modelContext
    @Binding var selectedBaby: Baby?

    @State private var showingAddBaby = false
    @State private var editingBaby: Baby?

    var body: some View {
        NavigationStack {
            Group {
                if babies.isEmpty {
                    ContentUnavailableView(
                        "No profiles yet",
                        systemImage: "person.crop.circle.badge.plus",
                        description: Text("Add a baby profile to get started")
                    )
                } else {
                    List {
                        ForEach(babies) { baby in
                            BabyRowView(
                                baby: baby,
                                isSelected: selectedBaby?.persistentModelID == baby.persistentModelID
                            )
                            .contentShape(Rectangle())
                            .onTapGesture { selectedBaby = baby }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) { delete(baby) } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                Button { editingBaby = baby } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Profiles")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingAddBaby = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddBaby) {
                BabyFormView()
            }
            .sheet(item: $editingBaby) { baby in
                BabyFormView(baby: baby)
            }
        }
    }

    private func delete(_ baby: Baby) {
        NotificationManager.shared.cancelAllNotifications(for: baby)
        if selectedBaby?.persistentModelID == baby.persistentModelID {
            selectedBaby = nil
        }
        modelContext.delete(baby)
    }
}

private struct BabyRowView: View {
    let baby: Baby
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(Color(hex: baby.colorHex))
                .frame(width: 44, height: 44)
                .overlay(
                    Text(baby.name.prefix(1).uppercased())
                        .font(.headline)
                        .foregroundStyle(.white)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(baby.name)
                    .font(.headline)
                Text(baby.age)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color(hex: baby.colorHex))
                    .font(.title3)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    BabyListView(selectedBaby: .constant(nil))
        .modelContainer(previewContainer)
}
