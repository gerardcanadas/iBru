import SwiftUI
import SwiftData

struct DashboardView: View {
    @Query(sort: \Baby.name) private var babies: [Baby]
    let baby: Baby?

    @Query private var allQuickDoses: [QuickDoseRecord]
    @Environment(\.modelContext) private var modelContext

    @State private var showingAddPlan = false
    @State private var showingQuickDose = false
    @State private var selectedPlan: MedicationPlan?
    @State private var planToStop: MedicationPlan?
    @State private var quickDoseToDelete: QuickDoseRecord?

    private var activeBaby: Baby? { baby }
    private var accentColor: Color { Color(hex: baby?.colorHex ?? "#5B8DEF") }

    private var activePlans: [MedicationPlan] {
        (baby?.plans ?? []).filter { $0.isActive }.sorted { $0.medicationName < $1.medicationName }
    }

    private var overdueCount: Int {
        activePlans.reduce(0) { $0 + DoseScheduler.overdueTimes(for: $1).count }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let baby {
                        babyHeader(baby)
                        overallStatus(baby)
                        quickDoseButton(baby)
                        plansSection(baby)
                        quickDosesSection(baby)
                    } else {
                        emptyState
                    }
                }
                .padding()
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if let baby {
                    ToolbarItem(placement: .primaryAction) {
                        Button { showingAddPlan = true } label: {
                            Image(systemName: "plus")
                        }
                    }
                    ToolbarItem(placement: .secondaryAction) {
                        NavigationLink {
                            PlanListView(baby: baby)
                        } label: {
                            Label("Manage medications", systemImage: "list.bullet")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddPlan) {
                if let baby { PlanFormView(baby: baby) }
            }
            .sheet(isPresented: $showingQuickDose) {
                if let baby { QuickDoseFormView(baby: baby) }
            }
            .confirmationDialog(
                "Delete quick dose?",
                isPresented: Binding(get: { quickDoseToDelete != nil }, set: { if !$0 { quickDoseToDelete = nil } }),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let r = quickDoseToDelete { deleteQuickDose(r) }
                    quickDoseToDelete = nil
                }
                Button("Cancel", role: .cancel) { quickDoseToDelete = nil }
            }
            .navigationDestination(item: $selectedPlan) { plan in
                HistoryView(plan: plan)
            }
            .confirmationDialog(
                "Stop \(planToStop?.medicationName ?? "medication")?",
                isPresented: Binding(get: { planToStop != nil }, set: { if !$0 { planToStop = nil } }),
                titleVisibility: .visible
            ) {
                Button("Stop treatment", role: .destructive) {
                    if let plan = planToStop { stopTreatment(plan) }
                    planToStop = nil
                }
                Button("Cancel", role: .cancel) { planToStop = nil }
            } message: {
                Text("Future doses will be removed. Your dose history will be kept.")
            }
        }
    }

    private var todayQuickDoses: [QuickDoseRecord] {
        guard let babyId = baby?.id else { return [] }
        return allQuickDoses
            .filter { $0.baby?.id == babyId && Calendar.current.isDateInToday($0.givenAt) }
            .sorted { $0.givenAt > $1.givenAt }
    }

    private func deleteQuickDose(_ record: QuickDoseRecord) {
        let id = record.id
        modelContext.delete(record)
        Task { await FirestoreService.shared.delete(quickDoseId: id) }
    }

    private func stopTreatment(_ plan: MedicationPlan) {
        plan.stoppedDate = .now
        NotificationManager.shared.cancelAllNotifications(for: plan)
        Task { await FirestoreService.shared.save(plan) }
    }

    private func babyHeader(_ baby: Baby) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(accentColor)
                .frame(width: 52, height: 52)
                .overlay(
                    Text(baby.name.prefix(1).uppercased())
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(baby.name)
                    .font(.title2.bold())
                Text(baby.age + " old")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private func overallStatus(_ baby: Baby) -> some View {
        HStack(spacing: 12) {
            StatusPillView(
                icon: "pill.fill",
                label: "\(activePlans.count)",
                caption: "medications",
                color: accentColor
            )
            StatusPillView(
                icon: "exclamationmark.triangle.fill",
                label: "\(overdueCount)",
                caption: "overdue",
                color: overdueCount > 0 ? .orange : .secondary
            )
            if let next = DoseScheduler.nextSlot(for: activePlans) {
                StatusPillView(
                    icon: "clock.fill",
                    label: next.scheduledTime.formatted(date: .omitted, time: .shortened),
                    caption: "next dose",
                    color: .blue
                )
            }
        }
    }

    private func quickDoseButton(_ baby: Baby) -> some View {
        Button { showingQuickDose = true } label: {
            Label("Quick Dose", systemImage: "pills.fill")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
    }

    private func quickDosesSection(_ baby: Baby) -> some View {
        Group {
            if !todayQuickDoses.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Quick doses today")
                        .font(.headline)
                        .padding(.top, 4)

                    ForEach(todayQuickDoses) { record in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(record.medicationName)
                                    .font(.subheadline.weight(.medium))
                                Text(record.doseSummary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(record.timeLabel)
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .contextMenu {
                            Button(role: .destructive) {
                                quickDoseToDelete = record
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }

    private func plansSection(_ baby: Baby) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Medications")
                .font(.headline)
                .padding(.top, 4)

            if activePlans.isEmpty {
                Button { showingAddPlan = true } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add first medication")
                    }
                    .font(.subheadline)
                    .foregroundStyle(accentColor)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(accentColor.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            } else {
                ForEach(activePlans) { plan in
                    MedicationCardView(plan: plan, accentColor: accentColor)
                        .onTapGesture { selectedPlan = plan }
                        .contextMenu {
                            Button(role: .destructive) { planToStop = plan } label: {
                                Label("Stop treatment", systemImage: "stop.circle")
                            }
                        }
                }
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No profile selected",
            systemImage: "person.crop.circle",
            description: Text("Go to Profiles to add or select a baby")
        )
        .padding(.top, 60)
    }
}

private struct StatusPillView: View {
    let icon: String
    let label: String
    let caption: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(label)
                .font(.headline.monospacedDigit())
            Text(caption)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    let container = previewContainer
    let baby = try! container.mainContext.fetch(FetchDescriptor<Baby>()).first!
    return DashboardView(baby: baby)
        .modelContainer(container)
}
