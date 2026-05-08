import SwiftUI
import SwiftData

struct PlanListView: View {
    @Environment(\.modelContext) private var modelContext
    let baby: Baby

    @State private var showingAddPlan = false
    @State private var editingPlan: MedicationPlan?
    @State private var planToDelete: MedicationPlan?

    private var activePlans: [MedicationPlan] {
        baby.plans.filter { $0.isActive }.sorted { $0.medicationName < $1.medicationName }
    }
    private var pastPlans: [MedicationPlan] {
        baby.plans.filter { !$0.isActive }.sorted { ($0.endDate ?? .distantFuture) > ($1.endDate ?? .distantFuture) }
    }

    var body: some View {
        List {
            if !activePlans.isEmpty {
                Section("Active") {
                    ForEach(activePlans) { plan in
                        PlanRowView(plan: plan)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) { planToDelete = plan } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                Button { editingPlan = plan } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                    }
                }
            }
            if !pastPlans.isEmpty {
                Section("Past") {
                    ForEach(pastPlans) { plan in
                        PlanRowView(plan: plan)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) { delete(plan) } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            }
            if activePlans.isEmpty && pastPlans.isEmpty {
                ContentUnavailableView(
                    "No medications",
                    systemImage: "pill",
                    description: Text("Add a medication plan for \(baby.name)")
                )
            }
        }
        .navigationTitle("Medications")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingAddPlan = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .confirmationDialog(
            "Stop \(planToDelete?.medicationName ?? "medication")?",
            isPresented: Binding(get: { planToDelete != nil }, set: { if !$0 { planToDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete Schedule", role: .destructive) {
                if let plan = planToDelete { delete(plan) }
                planToDelete = nil
            }
            Button("Cancel", role: .cancel) { planToDelete = nil }
        } message: {
            Text("This will remove the active schedule and all recorded doses. This cannot be undone.")
        }
        .sheet(isPresented: $showingAddPlan) {
            PlanFormView(baby: baby)
        }
        .sheet(item: $editingPlan) { plan in
            PlanFormView(baby: baby, plan: plan)
        }
    }

    private func delete(_ plan: MedicationPlan) {
        let id = plan.id
        NotificationManager.shared.cancelAllNotifications(for: plan)
        modelContext.delete(plan)
        Task { await FirestoreService.shared.delete(planId: id) }
    }
}

private struct PlanRowView: View {
    let plan: MedicationPlan

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(plan.medicationName)
                    .font(.headline)
                Spacer()
                Text(plan.isActive ? "Active" : "Ended")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(plan.isActive ? Color.green.opacity(0.15) : Color.secondary.opacity(0.15))
                    .foregroundStyle(plan.isActive ? .green : .secondary)
                    .clipShape(Capsule())
            }
            Text("\(plan.doseSummary) · \(plan.frequencySummary)")
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
        PlanListView(baby: baby)
    }
    .modelContainer(container)
}
