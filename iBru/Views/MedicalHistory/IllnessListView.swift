import SwiftUI
import SwiftData

struct IllnessListView: View {
    @Environment(\.modelContext) private var modelContext
    let baby: Baby

    @State private var showingAdd = false
    @State private var editingRecord: IllnessRecord?
    @State private var recordToDelete: IllnessRecord?

    private var ongoingRecords: [IllnessRecord] {
        baby.illnesses.filter { $0.isOngoing }.sorted { $0.startDate > $1.startDate }
    }
    private var pastRecords: [IllnessRecord] {
        baby.illnesses.filter { !$0.isOngoing }.sorted { $0.startDate > $1.startDate }
    }

    var body: some View {
        List {
            if !ongoingRecords.isEmpty {
                Section("Ongoing") {
                    ForEach(ongoingRecords) { record in
                        NavigationLink { IllnessDetailView(record: record) } label: {
                            IllnessRowView(record: record)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) { recordToDelete = record } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button { editingRecord = record } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                    }
                }
            }
            if !pastRecords.isEmpty {
                Section("Past") {
                    ForEach(pastRecords) { record in
                        NavigationLink { IllnessDetailView(record: record) } label: {
                            IllnessRowView(record: record)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) { recordToDelete = record } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button { editingRecord = record } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                    }
                }
            }
            if ongoingRecords.isEmpty && pastRecords.isEmpty {
                ContentUnavailableView(
                    "No illness records",
                    systemImage: "stethoscope",
                    description: Text("Tap + to log an illness episode for \(baby.name)")
                )
            }
        }
        .navigationTitle("Medical History")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingAdd = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .confirmationDialog(
            "Delete \(recordToDelete?.title ?? "record")?",
            isPresented: Binding(get: { recordToDelete != nil }, set: { if !$0 { recordToDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let record = recordToDelete { modelContext.delete(record) }
                recordToDelete = nil
            }
            Button("Cancel", role: .cancel) { recordToDelete = nil }
        } message: {
            Text("This will permanently delete this illness record. Linked medication plans will not be affected.")
        }
        .sheet(isPresented: $showingAdd) {
            IllnessFormView(baby: baby)
        }
        .sheet(item: $editingRecord) { record in
            IllnessFormView(baby: baby, illness: record)
        }
    }
}

private struct IllnessRowView: View {
    let record: IllnessRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(record.title)
                    .font(.headline)
                Spacer()
                Text(record.isOngoing ? "Ongoing" : "Recovered")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(record.isOngoing ? Color.orange.opacity(0.15) : Color.green.opacity(0.15))
                    .foregroundStyle(record.isOngoing ? .orange : .green)
                    .clipShape(Capsule())
            }
            Text(record.durationSummary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if !record.plans.isEmpty {
                Text(record.plans.map(\.medicationName).joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
