import SwiftUI
import SwiftData

struct VaccineDetailView: View {
    @Bindable var vaccine: VaccineRecord
    @Environment(\.modelContext) private var modelContext
    @State private var showingEdit = false

    var body: some View {
        List {
            Section {
                LabeledContent("Status") {
                    Text(vaccine.statusLabel)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(vaccine.isReceived ? Color.green.opacity(0.15) : Color.secondary.opacity(0.1))
                        .foregroundStyle(vaccine.isReceived ? .green : .secondary)
                        .clipShape(Capsule())
                }
                LabeledContent("Recommended age", value: vaccine.recommendedAgeLabel)
                if let given = vaccine.givenDate {
                    LabeledContent("Given on", value: given.formatted(date: .abbreviated, time: .omitted))
                }
            }

            if !vaccine.notes.isEmpty {
                Section("Notes") {
                    Text(vaccine.notes)
                        .foregroundStyle(.secondary)
                }
            }

            if !vaccine.isReceived {
                Section {
                    Button {
                        vaccine.givenDate = .now
                        Task { await FirestoreService.shared.save(vaccine) }
                    } label: {
                        Label("Mark as Received", systemImage: "checkmark.circle")
                            .foregroundStyle(.green)
                    }
                }
            }
        }
        .navigationTitle(vaccine.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { showingEdit = true }
            }
        }
        .sheet(isPresented: $showingEdit) {
            VaccineFormView(baby: vaccine.baby!, vaccine: vaccine)
        }
    }
}
