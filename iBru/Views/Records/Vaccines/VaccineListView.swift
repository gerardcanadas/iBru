import SwiftUI
import SwiftData

struct VaccineListView: View {
    @Environment(\.modelContext) private var modelContext
    let baby: Baby

    @State private var showingAdd = false
    @State private var editingVaccine: VaccineRecord?
    @State private var vaccineToDelete: VaccineRecord?

    private var upcoming: [VaccineRecord] {
        baby.vaccines
            .filter { !$0.isReceived }
            .sorted { $0.recommendedAgeDays < $1.recommendedAgeDays }
    }

    private var received: [VaccineRecord] {
        baby.vaccines
            .filter { $0.isReceived }
            .sorted { ($0.givenDate ?? .distantPast) > ($1.givenDate ?? .distantPast) }
    }

    var body: some View {
        List {
            if !upcoming.isEmpty {
                Section("Upcoming") {
                    ForEach(upcoming) { vaccine in
                        NavigationLink { VaccineDetailView(vaccine: vaccine) } label: {
                            VaccineRowView(vaccine: vaccine)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) { vaccineToDelete = vaccine } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button { editingVaccine = vaccine } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                    }
                }
            }

            if !received.isEmpty {
                Section("Received") {
                    ForEach(received) { vaccine in
                        NavigationLink { VaccineDetailView(vaccine: vaccine) } label: {
                            VaccineRowView(vaccine: vaccine)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) { vaccineToDelete = vaccine } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button { editingVaccine = vaccine } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                    }
                }
            }

            if upcoming.isEmpty && received.isEmpty {
                ContentUnavailableView(
                    "No vaccines logged",
                    systemImage: "syringe",
                    description: Text("Tap + to add vaccines for \(baby.name)")
                )
            }
        }
        .navigationTitle("Vaccines")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingAdd = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .confirmationDialog(
            "Delete \(vaccineToDelete?.name ?? "vaccine")?",
            isPresented: Binding(get: { vaccineToDelete != nil }, set: { if !$0 { vaccineToDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let v = vaccineToDelete {
                    let id = v.id
                    modelContext.delete(v)
                    Task { await FirestoreService.shared.delete(vaccineId: id) }
                }
                vaccineToDelete = nil
            }
            Button("Cancel", role: .cancel) { vaccineToDelete = nil }
        }
        .sheet(isPresented: $showingAdd) {
            VaccineFormView(baby: baby)
        }
        .sheet(item: $editingVaccine) { vaccine in
            VaccineFormView(baby: baby, vaccine: vaccine)
        }
    }
}

private struct VaccineRowView: View {
    let vaccine: VaccineRecord

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(vaccine.name)
                    .font(.headline)
                Text(vaccine.recommendedAgeLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(vaccine.statusLabel)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(vaccine.isReceived ? Color.green.opacity(0.15) : Color.secondary.opacity(0.1))
                .foregroundStyle(vaccine.isReceived ? .green : .secondary)
                .clipShape(Capsule())
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    let container = previewContainer
    let baby = try! container.mainContext.fetch(FetchDescriptor<Baby>()).first!
    return NavigationStack {
        VaccineListView(baby: baby)
    }
    .modelContainer(container)
}
