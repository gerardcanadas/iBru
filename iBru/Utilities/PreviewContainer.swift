import SwiftData
import Foundation

@MainActor
let previewContainer: ModelContainer = {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Baby.self, MedicationPlan.self, DoseRecord.self,
        configurations: config
    )
    let ctx = container.mainContext

    let baby = Baby(name: "Pau", birthDate: Date.now.addingTimeInterval(-86400 * 90), colorHex: "#5B8DEF")
    ctx.insert(baby)

    let plan1 = MedicationPlan(
        medicationName: "Paracetamol",
        doseAmount: 5,
        doseUnit: "ml",
        frequencyUnit: .everyNHours,
        frequencyValue: 8,
        startDate: Calendar.current.date(byAdding: .hour, value: -10, to: .now)!
    )
    plan1.baby = baby
    ctx.insert(plan1)

    let plan2 = MedicationPlan(
        medicationName: "Vitamin D",
        doseAmount: 0.5,
        doseUnit: "ml",
        frequencyUnit: .timesPerDay,
        frequencyValue: 1,
        startDate: Calendar.current.date(byAdding: .day, value: -3, to: .now)!,
        endDate: Calendar.current.date(byAdding: .day, value: 7, to: .now)!
    )
    plan2.baby = baby
    ctx.insert(plan2)

    // Simulate one taken dose for plan1 today
    if let firstSlot = DoseScheduler.scheduledTimes(for: plan1, on: .now).first {
        let record = DoseRecord(scheduledDate: firstSlot, status: .taken)
        record.plan = plan1
        ctx.insert(record)
    }

    let quickDose = QuickDoseRecord(
        medicationName: "Paracetamol",
        doseAmount: 5,
        doseUnit: "ml",
        givenAt: Calendar.current.date(byAdding: .hour, value: -3, to: .now)!,
        notes: "Fever at night"
    )
    quickDose.baby = baby
    ctx.insert(quickDose)

    return container
}()
