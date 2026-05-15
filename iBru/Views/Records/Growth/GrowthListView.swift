import SwiftUI
import SwiftData
import Charts

struct GrowthListView: View {
    @Environment(\.modelContext) private var modelContext
    let baby: Baby

    @State private var showingAdd = false
    @State private var editingRecord: GrowthRecord?
    @State private var recordToDelete: GrowthRecord?
    @State private var selectedMeasurement: GrowthMeasurement = .weight

    private var sortedRecords: [GrowthRecord] {
        baby.growthRecords.sorted { $0.date > $1.date }
    }

    var body: some View {
        List {
            growthChartSection

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
    private var growthChartSection: some View {
        Section {
            Picker("Measurement", selection: $selectedMeasurement) {
                ForEach(GrowthMeasurement.allCases) { m in
                    Text(m.label).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .padding(.vertical, 4)

            GrowthPercentileChartView(baby: baby, measurement: selectedMeasurement)
                .frame(height: 200)
                .padding(.vertical, 8)
        } header: {
            Text("Growth Charts")
        }
    }
}

// MARK: - Measurement type

private enum GrowthMeasurement: String, CaseIterable, Identifiable {
    case weight, height, head
    var id: String { rawValue }

    var label: String {
        switch self {
        case .weight: String(localized: "Weight")
        case .height: String(localized: "Height")
        case .head:   String(localized: "Head")
        }
    }

    var unit: String {
        switch self {
        case .weight: "kg"
        case .height, .head: "cm"
        }
    }

    func value(from record: GrowthRecord) -> Double? {
        switch self {
        case .weight: record.weightKg
        case .height: record.heightCm
        case .head:   record.headCircumferenceCm
        }
    }

    func whoTable(sex: BabySex) -> [PercentilePoint] {
        switch self {
        case .weight: WHOGrowthData.weightPoints(sex: sex)
        case .height: WHOGrowthData.heightPoints(sex: sex)
        case .head:   WHOGrowthData.headPoints(sex: sex)
        }
    }
}

// MARK: - Percentile chart

private struct GrowthPercentileChartView: View {
    let baby: Baby
    let measurement: GrowthMeasurement

    private func ageMonths(_ date: Date) -> Double {
        let days = Calendar.current.dateComponents([.day], from: baby.birthDate, to: date).day ?? 0
        return Double(days) / 30.4375
    }

    private var babyPoints: [(ageMonths: Double, value: Double)] {
        baby.growthRecords
            .sorted { $0.date < $1.date }
            .compactMap { r in
                guard let val = measurement.value(from: r) else { return nil }
                return (ageMonths(r.date), val)
            }
    }

    private var bandPoints: [PercentilePoint] {
        let table = measurement.whoTable(sex: baby.sex)
        return stride(from: 0.0, through: 60.0, by: 0.5).compactMap {
            WHOGrowthData.interpolated(ageMonths: $0, from: table)
        } + [table.last].compactMap { $0 }
    }

    private var babyIsPartlyBeyond60Months: Bool {
        babyPoints.contains { $0.ageMonths > 60 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Chart {
                // Shaded WHO 3rd–97th percentile band
                ForEach(bandPoints) { pt in
                    AreaMark(
                        x: .value("Age (months)", pt.ageMonths),
                        yStart: .value("P3", pt.p3),
                        yEnd: .value("P97", pt.p97)
                    )
                    .foregroundStyle(Color.green.opacity(0.14))
                    .interpolationMethod(.monotone)
                }
                // Dashed 50th percentile (median) line
                ForEach(bandPoints) { pt in
                    LineMark(
                        x: .value("Age (months)", pt.ageMonths),
                        y: .value("Median", pt.p50)
                    )
                    .foregroundStyle(Color.green.opacity(0.55))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                    .interpolationMethod(.monotone)
                }
                // Baby's actual measurements
                ForEach(babyPoints.indices, id: \.self) { i in
                    let pt = babyPoints[i]
                    LineMark(
                        x: .value("Age (months)", pt.ageMonths),
                        y: .value(measurement.unit, pt.value)
                    )
                    .foregroundStyle(Color.blue)
                    .interpolationMethod(.monotone)
                }
                ForEach(babyPoints.indices, id: \.self) { i in
                    let pt = babyPoints[i]
                    PointMark(
                        x: .value("Age (months)", pt.ageMonths),
                        y: .value(measurement.unit, pt.value)
                    )
                    .foregroundStyle(Color.blue)
                    .symbolSize(40)
                }
            }
            .chartYAxisLabel(measurement.unit)
            .chartXAxisLabel("Age (months)")

            if babyPoints.isEmpty {
                Text("Add measurements to track your baby's progress")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if babyIsPartlyBeyond60Months {
                Text("WHO reference data covers 0–60 months")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Row

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
