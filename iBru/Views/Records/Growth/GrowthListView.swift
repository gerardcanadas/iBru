import SwiftUI
import SwiftData
import Charts

struct GrowthListView: View {
    @Environment(\.modelContext) private var modelContext
    let baby: Baby

    @State private var showingAdd = false
    @State private var editingRecord: GrowthRecord?
    @State private var recordToDelete: GrowthRecord?

    private var sortedRecords: [GrowthRecord] {
        baby.growthRecords.sorted { $0.date > $1.date }
    }

    var body: some View {
        List {
            if !sortedRecords.isEmpty {
                weightChartSection
            }

            if sortedRecords.isEmpty {
                ContentUnavailableView(
                    "No growth records",
                    systemImage: "ruler",
                    description: Text("Tap + to log a measurement for \(baby.name)")
                )
            } else {
                Section("Measurements") {
                    ForEach(sortedRecords) { record in
                        NavigationLink { GrowthDetailView(record: record) } label: {
                            GrowthRowView(record: record)
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
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingAdd = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .confirmationDialog(
            "Delete measurement?",
            isPresented: Binding(get: { recordToDelete != nil }, set: { if !$0 { recordToDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let r = recordToDelete {
                    let id = r.id
                    modelContext.delete(r)
                    Task { await FirestoreService.shared.delete(growthId: id) }
                }
                recordToDelete = nil
            }
            Button("Cancel", role: .cancel) { recordToDelete = nil }
        }
        .sheet(isPresented: $showingAdd) {
            GrowthFormView(baby: baby)
        }
        .sheet(item: $editingRecord) { r in
            GrowthFormView(baby: baby, record: r)
        }
    }

    @ViewBuilder
    private var weightChartSection: some View {
        let weightPoints = sortedRecords.reversed().filter { $0.weightKg != nil }
        if weightPoints.count >= 2 {
            Section("Weight over time") {
                Chart(weightPoints) { r in
                    LineMark(
                        x: .value("Date", r.date),
                        y: .value("kg", r.weightKg!)
                    )
                    .foregroundStyle(Color.blue)
                    PointMark(
                        x: .value("Date", r.date),
                        y: .value("kg", r.weightKg!)
                    )
                    .foregroundStyle(Color.blue)
                }
                .chartYAxisLabel("kg")
                .frame(height: 160)
                .padding(.vertical, 8)
            }
        }
    }
}

private struct GrowthRowView: View {
    let record: GrowthRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(record.date.formatted(date: .abbreviated, time: .omitted))
                .font(.headline)
            Text(record.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    let container = previewContainer
    let baby = try! container.mainContext.fetch(FetchDescriptor<Baby>()).first!
    return NavigationStack {
        GrowthListView(baby: baby)
    }
    .modelContainer(container)
}
