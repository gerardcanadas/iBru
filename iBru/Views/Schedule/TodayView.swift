import SwiftUI
import SwiftData

struct TodayView: View {
    let baby: Baby?

    private var activePlans: [MedicationPlan] {
        (baby?.plans ?? []).filter { $0.isActive }
    }

    private struct DoseItem: Identifiable {
        let id = UUID()
        let slot: Date
        let plan: MedicationPlan
    }

    private var todayItems: [DoseItem] {
        activePlans
            .flatMap { plan in
                DoseScheduler.scheduledTimes(for: plan, on: .now)
                    .map { DoseItem(slot: $0, plan: plan) }
            }
            .sorted { $0.slot < $1.slot }
    }

    var body: some View {
        NavigationStack {
            Group {
                if baby == nil {
                    noBabyView
                } else if todayItems.isEmpty {
                    ContentUnavailableView(
                        "No doses today",
                        systemImage: "pill",
                        description: Text("Add a medication plan to get started")
                    )
                } else {
                    List {
                        ForEach(groupedItems, id: \.plan.persistentModelID) { group in
                            PlanGroupSection(group: group)
                        }
                    }
                }
            }
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private var noBabyView: some View {
        ContentUnavailableView(
            "No profile selected",
            systemImage: "person.crop.circle",
            description: Text("Add a baby profile in the Profiles tab")
        )
    }

    private struct PlanGroup {
        let plan: MedicationPlan
        let items: [DoseItem]
    }

    // Extracted to avoid ChartContentBuilder ambiguity in Xcode 16
    private struct PlanGroupSection: View {
        let group: PlanGroup
        var body: some View {
            Section(group.plan.medicationName) {
                ForEach(group.items) { item in
                    DoseRowView(slot: item.slot, plan: item.plan)
                }
            }
        }
    }

    private var groupedItems: [PlanGroup] {
        var byPlan: [ObjectIdentifier: (MedicationPlan, [DoseItem])] = [:]
        for item in todayItems {
            let key = ObjectIdentifier(item.plan)
            if byPlan[key] == nil {
                byPlan[key] = (item.plan, [])
            }
            byPlan[key]!.1.append(item)
        }
        return byPlan.values.map { PlanGroup(plan: $0.0, items: $0.1) }
            .sorted { $0.plan.medicationName < $1.plan.medicationName }
    }
}

#Preview {
    let container = previewContainer
    let baby = try! container.mainContext.fetch(FetchDescriptor<Baby>()).first!
    return TodayView(baby: baby)
        .modelContainer(container)
}
