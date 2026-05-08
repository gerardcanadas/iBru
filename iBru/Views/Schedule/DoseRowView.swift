import SwiftUI
import SwiftData

struct DoseRowView: View {
    @Environment(\.modelContext) private var modelContext

    let slot: Date
    let plan: MedicationPlan

    private var record: DoseRecord? { DoseScheduler.record(for: slot, in: plan) }
    private var isOverdue: Bool { slot < .now && record == nil }
    private var isTaken: Bool { record?.status == .taken }
    private var isSkipped: Bool { record?.status == .skipped }

    var body: some View {
        HStack(spacing: 14) {
            statusIcon

            VStack(alignment: .leading, spacing: 2) {
                Text(slot, style: .time)
                    .font(.headline)
                    .foregroundStyle(isOverdue ? .orange : .primary)
                Text(plan.doseSummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if isSkipped {
                    Text("Skipped")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if record == nil {
                Button { logDose(.taken) } label: {
                    Image(systemName: "checkmark.circle")
                        .font(.title2)
                        .foregroundStyle(.green)
                }
                .buttonStyle(.plain)
            } else if isTaken, let r = record {
                Text(r.recordedDate, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if record == nil {
                Button { logDose(.skipped) } label: {
                    Label("Skip", systemImage: "forward.fill")
                }
                .tint(.orange)
            }
        }
    }

    private var statusIcon: some View {
        ZStack {
            Circle()
                .fill(iconBackground)
                .frame(width: 36, height: 36)
            Image(systemName: iconName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(iconForeground)
        }
    }

    private var iconName: String {
        if isTaken { return "checkmark" }
        if isSkipped { return "forward.fill" }
        if isOverdue { return "exclamationmark" }
        return "clock"
    }

    private var iconBackground: Color {
        if isTaken { return .green.opacity(0.15) }
        if isSkipped { return .secondary.opacity(0.15) }
        if isOverdue { return .orange.opacity(0.15) }
        return .blue.opacity(0.10)
    }

    private var iconForeground: Color {
        if isTaken { return .green }
        if isSkipped { return .secondary }
        if isOverdue { return .orange }
        return .blue
    }

    private func logDose(_ status: DoseStatus) {
        let r = DoseRecord(scheduledDate: slot, status: status)
        r.plan = plan
        modelContext.insert(r)
        if status == .taken {
            NotificationManager.shared.cancelNotification(id: notificationId)
        }
        Task { await FirestoreService.shared.save(r) }
    }

    private var notificationId: String {
        "\(plan.persistentModelID)-\(slot.timeIntervalSince1970)"
    }
}
