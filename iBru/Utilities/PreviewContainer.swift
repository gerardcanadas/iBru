import SwiftData
import Foundation

@MainActor
let previewContainer: ModelContainer = {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Baby.self, MedicationPlan.self, DoseRecord.self, IllnessRecord.self, QuickDoseRecord.self,
        TemperatureReading.self, VaccineRecord.self, GrowthRecord.self, DailyNote.self,
        configurations: config
    )
    let ctx = container.mainContext

    let baby = Baby(name: "Pau", birthDate: Date.now.addingTimeInterval(-86400 * 90), colorHex: "#5B8DEF")
    baby.sex = .male
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

    // Sample DoseRecords for Insights preview
    let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: .now)!
    let r2 = DoseRecord(scheduledDate: twoDaysAgo, status: .skipped)
    r2.plan = plan1; ctx.insert(r2)
    let r3 = DoseRecord(scheduledDate: Calendar.current.date(byAdding: .day, value: -5, to: .now)!, status: .taken)
    r3.plan = plan1; ctx.insert(r3)

    // Sample IllnessRecords for Insights preview
    let coldStart = Calendar.current.date(byAdding: .day, value: -20, to: .now)!
    let coldEnd   = Calendar.current.date(byAdding: .day, value: -18, to: .now)!
    let cold = IllnessRecord(title: "Cold", startDate: coldStart, endDate: coldEnd)
    cold.baby = baby; ctx.insert(cold)

    let bronchStart = Calendar.current.date(byAdding: .day, value: -10, to: .now)!
    let bronch = IllnessRecord(title: "Bronchitis", startDate: bronchStart, endDate: nil)
    bronch.baby = baby; ctx.insert(bronch)

    let feverStart = Calendar.current.date(byAdding: .day, value: -60, to: .now)!
    let feverEnd   = Calendar.current.date(byAdding: .day, value: -55, to: .now)!
    let fever = IllnessRecord(title: "Fever", startDate: feverStart, endDate: feverEnd)
    fever.baby = baby; ctx.insert(fever)

    // Sample temperature readings for the bronchitis illness
    let temp1 = TemperatureReading(date: Calendar.current.date(byAdding: .hour, value: -48, to: .now)!, valueCelsius: 38.2)
    temp1.illness = bronch; ctx.insert(temp1)
    let temp2 = TemperatureReading(date: Calendar.current.date(byAdding: .hour, value: -24, to: .now)!, valueCelsius: 37.8)
    temp2.illness = bronch; ctx.insert(temp2)

    // Sample vaccines
    let mmr = VaccineRecord(name: "MMR", recommendedAgeDays: 365)
    mmr.baby = baby; ctx.insert(mmr)
    let dtap = VaccineRecord(name: "DTaP-1", recommendedAgeDays: 60, givenDate: Calendar.current.date(byAdding: .day, value: -30, to: .now)!)
    dtap.baby = baby; ctx.insert(dtap)

    // Sample growth records
    let g1 = GrowthRecord(date: Calendar.current.date(byAdding: .day, value: -60, to: .now)!, weightKg: 5.5, heightCm: 60.0, headCircumferenceCm: 40.0)
    g1.baby = baby; ctx.insert(g1)
    let g2 = GrowthRecord(date: Calendar.current.date(byAdding: .day, value: -30, to: .now)!, weightKg: 6.2, heightCm: 63.0)
    g2.baby = baby; ctx.insert(g2)
    let g3 = GrowthRecord(date: .now, weightKg: 6.8, heightCm: 65.5, headCircumferenceCm: 42.0)
    g3.baby = baby; ctx.insert(g3)

    // Sample daily notes (attached to bronchitis illness)
    let n1 = DailyNote(date: .now, content: "Ate well today, slept 4h in the afternoon.")
    n1.illness = bronch; ctx.insert(n1)
    let n2 = DailyNote(date: Calendar.current.date(byAdding: .day, value: -1, to: .now)!, content: "Fussy in the morning, better after nap.")
    n2.illness = bronch; ctx.insert(n2)
    let n3 = DailyNote(date: Calendar.current.date(byAdding: .day, value: -3, to: .now)!, content: "First time rolling over! Very excited.")
    n3.illness = bronch; ctx.insert(n3)

    return container
}()
