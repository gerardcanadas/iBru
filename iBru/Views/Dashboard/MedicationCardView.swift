import SwiftUI
import SwiftData

struct MedicationCardView: View {
    let plan: MedicationPlan
    let accentColor: Color

    private var scheduledToday: [Date] {
        DoseScheduler.scheduledTimes(for: plan, on: .now)
    }

    private var takenToday: Int {
        plan.records.filter {
            Calendar.current.isDateInToday($0.scheduledDate) && $0.status == .taken
        }.count
    }

    private var progress: Double {
        guard !scheduledToday.isEmpty else { return 0 }
        return Double(takenToday) / Double(scheduledToday.count)
    }

    private var overdueTimes: [Date] {
        DoseScheduler.overdueTimes(for: plan)
    }

    private var isOverdue: Bool { !overdueTimes.isEmpty }

    private var nextSlot: ScheduledSlot? {
        DoseScheduler.nextSlot(for: [plan])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(plan.medicationName)
                        .font(.headline)
                        .lineLimit(1)
                    Text(plan.doseSummary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(plan.frequencySummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                ProgressRingView(progress: progress, isOverdue: isOverdue, size: 54)
            }

            Divider()

            HStack {
                if isOverdue {
                    Label("\(overdueTimes.count) overdue", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else if let next = nextSlot {
                    Label("Next: \(next.scheduledTime, style: .time)", systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Label("All done today", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }

                Spacer()

                Text("\(takenToday)/\(scheduledToday.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(accentColor.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isOverdue ? Color.orange.opacity(0.5) : accentColor.opacity(0.25), lineWidth: 1.5)
        )
    }
}

#Preview {
    let container = previewContainer
    let plan = try! container.mainContext.fetch(FetchDescriptor<MedicationPlan>()).first!
    return MedicationCardView(plan: plan, accentColor: .blue)
        .padding()
        .modelContainer(container)
}
