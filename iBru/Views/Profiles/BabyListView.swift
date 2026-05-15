import SwiftUI
import SwiftData

struct BabyListView: View {
    @Query(filter: #Predicate<Baby> { $0.isActive == true }, sort: \Baby.name) private var babies: [Baby]
    @Query(filter: #Predicate<Baby> { $0.isActive == false }, sort: \Baby.name) private var archivedBabies: [Baby]
    @Environment(\.modelContext) private var modelContext
    @Binding var selectedBaby: Baby?

    @State private var showingAddBaby = false
    @State private var editingBaby: Baby?
    @State private var babyToArchive: Baby?

    var body: some View {
        NavigationStack {
            Group {
                if babies.isEmpty && archivedBabies.isEmpty {
                    ContentUnavailableView(
                        "No profiles yet",
                        systemImage: "person.crop.circle.badge.plus",
                        description: Text("Add a baby profile to get started")
                    )
                } else {
                    List {
                        if !babies.isEmpty {
                            Section {
                                ForEach(babies) { baby in
                                    BabyRowView(
                                        baby: baby,
                                        isSelected: selectedBaby?.persistentModelID == baby.persistentModelID
                                    )
                                    .contentShape(Rectangle())
                                    .onTapGesture { selectedBaby = baby }
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) { babyToArchive = baby } label: {
                                            Label("Archive", systemImage: "archivebox")
                                        }
                                        Button { editingBaby = baby } label: {
                                            Label("Edit", systemImage: "pencil")
                                        }
                                        .tint(.blue)
                                    }
                                }
                            }
                        }

                        if !archivedBabies.isEmpty {
                            Section("Archived") {
                                ForEach(archivedBabies) { baby in
                                    HStack {
                                        BabyRowView(baby: baby, isSelected: false)
                                        Spacer()
                                        Button("Restore") { restore(baby) }
                                            .buttonStyle(.bordered)
                                            .tint(.green)
                                            .font(.subheadline)
                                    }
                                }
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
                ToolbarItem(placement: .secondaryAction) {
                    NavigationLink(destination: FamilySettingsView()) {
                        Label("Family Settings", systemImage: "person.2.circle")
                    }
                }
            }
            .sheet(isPresented: $showingAddBaby) {
                BabyFormView()
            }
            .sheet(item: $editingBaby) { baby in
                BabyFormView(baby: baby)
            }
            .confirmationDialog(
                "Archive profile?",
                isPresented: Binding(get: { babyToArchive != nil }, set: { if !$0 { babyToArchive = nil } }),
                titleVisibility: .visible
            ) {
                Button("Archive", role: .destructive) {
                    if let b = babyToArchive { archive(b) }
                    babyToArchive = nil
                }
                Button("Cancel", role: .cancel) { babyToArchive = nil }
            } message: {
                Text("You can restore this profile later from the Archived section.")
            }
        }
    }

    private func archive(_ baby: Baby) {
        NotificationManager.shared.cancelAllNotifications(for: baby)
        if selectedBaby?.persistentModelID == baby.persistentModelID {
            selectedBaby = nil
        }
        baby.isActive = false
        Task { await FirestoreService.shared.save(baby) }
    }

    private func restore(_ baby: Baby) {
        baby.isActive = true
        Task { await FirestoreService.shared.save(baby) }
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
