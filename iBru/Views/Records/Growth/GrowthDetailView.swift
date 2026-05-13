import SwiftUI
import SwiftData

struct GrowthDetailView: View {
    @Bindable var record: GrowthRecord
    @State private var showingEdit = false

    var body: some View {
        List {
            Section {
                LabeledContent("Date", value: record.date.formatted(date: .abbreviated, time: .omitted))
                if let w = record.weightKg {
                    LabeledContent("Weight", value: String(format: "%.2f kg", w))
                }
                if let h = record.heightCm {
                    LabeledContent("Height", value: String(format: "%.1f cm", h))
                }
                if let hc = record.headCircumferenceCm {
                    LabeledContent("Head circumference", value: String(format: "%.1f cm", hc))
                }
            }

            if !record.notes.isEmpty {
                Section("Notes") {
                    Text(record.notes)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(record.date.formatted(date: .abbreviated, time: .omitted))
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { showingEdit = true }
            }
        }
        .sheet(isPresented: $showingEdit) {
            GrowthFormView(baby: record.baby!, record: record)
        }
    }
}
