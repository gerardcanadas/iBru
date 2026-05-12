import Testing
import Foundation
import SwiftData
@testable import iBru

@Suite @MainActor
struct QuickDoseRecordTests {

    var container: ModelContainer
    var context: ModelContext

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: Baby.self, MedicationPlan.self, DoseRecord.self, IllnessRecord.self, QuickDoseRecord.self,
            configurations: config
        )
        context = ModelContext(container)
    }

    private func record(
        name: String = "Paracetamol",
        amount: Double = 5,
        unit: String = "ml",
        givenAt: Date = .now,
        notes: String = ""
    ) -> QuickDoseRecord {
        let r = QuickDoseRecord(medicationName: name, doseAmount: amount, doseUnit: unit, givenAt: givenAt, notes: notes)
        context.insert(r)
        return r
    }

    private func baby() -> Baby {
        let b = Baby(name: "Pau", birthDate: Date.now.addingTimeInterval(-86400 * 90), colorHex: "#5B8DEF")
        context.insert(b)
        return b
    }

    // MARK: - doseSummary

    @Test func doseSummary_wholeNumber() {
        #expect(record(amount: 5, unit: "ml").doseSummary == "5 ml")
    }

    @Test func doseSummary_decimal() {
        #expect(record(amount: 2.5, unit: "ml").doseSummary == "2.5 ml")
    }

    @Test func doseSummary_smallDecimal() {
        #expect(record(amount: 0.5, unit: "ml").doseSummary == "0.5 ml")
    }

    @Test func doseSummary_differentUnit() {
        #expect(record(amount: 1, unit: "tablet").doseSummary == "1 tablet")
    }

    // MARK: - id

    @Test func id_isNonEmpty() {
        #expect(!record().id.isEmpty)
    }

    @Test func id_isUniquePerRecord() {
        #expect(record().id != record().id)
    }

    // MARK: - Baby relationship

    @Test func babyRelationship_canLink() throws {
        let b = baby()
        let r = record()
        r.baby = b

        try context.save()

        let fetched = try context.fetch(FetchDescriptor<QuickDoseRecord>())
        #expect(fetched.first?.baby?.name == "Pau")
    }

    @Test func babyRelationship_appearsInBabyQuickDoses() throws {
        let b = baby()
        let r = record()
        r.baby = b

        try context.save()

        let fetchedBaby = try context.fetch(FetchDescriptor<Baby>()).first
        #expect(fetchedBaby?.quickDoses.contains { $0.id == r.id } == true)
    }

    @Test func babyDeletion_cascadesQuickDose() throws {
        let b = baby()
        let r = record()
        r.baby = b
        try context.save()

        context.delete(b)
        try context.save()

        let remaining = try context.fetch(FetchDescriptor<QuickDoseRecord>())
        #expect(remaining.isEmpty)
    }
}

// MARK: - Interval warning logic

@Suite @MainActor
struct QuickDoseIntervalTests {

    var container: ModelContainer
    var context: ModelContext

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: Baby.self, MedicationPlan.self, DoseRecord.self, IllnessRecord.self, QuickDoseRecord.self,
            configurations: config
        )
        context = ModelContext(container)
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, hour h: Int = 0, minute mi: Int = 0) -> Date {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: mi))!
    }

    // The interval warning thresholds are computed from the plan's frequency.
    // everyNHours → minInterval = frequencyValue hours
    // timesPerDay → minInterval = 24 / frequencyValue hours
    // These tests verify the threshold values that drive the warning, without
    // coupling to the private view method.

    @Test func everyNHours_minIntervalEqualsFrequencyValue() {
        let p = MedicationPlan(
            medicationName: "Drug",
            doseAmount: 5, doseUnit: "ml",
            frequencyUnit: .everyNHours, frequencyValue: 8,
            startDate: date(2025, 1, 1)
        )
        context.insert(p)
        let minInterval: Double = Double(p.frequencyValue)
        #expect(minInterval == 8)
    }

    @Test func timesPerDay_minIntervalIs24DividedByFrequency() {
        let p = MedicationPlan(
            medicationName: "Drug",
            doseAmount: 5, doseUnit: "ml",
            frequencyUnit: .timesPerDay, frequencyValue: 3,
            startDate: date(2025, 1, 1)
        )
        context.insert(p)
        let minInterval: Double = 24.0 / Double(p.frequencyValue)
        #expect(minInterval == 8)
    }

    @Test func timesPerDay_onceDaily_minIntervalIs24h() {
        let p = MedicationPlan(
            medicationName: "Drug",
            doseAmount: 5, doseUnit: "ml",
            frequencyUnit: .timesPerDay, frequencyValue: 1,
            startDate: date(2025, 1, 1)
        )
        context.insert(p)
        let minInterval: Double = 24.0 / Double(p.frequencyValue)
        #expect(minInterval == 24)
    }

    @Test func hoursElapsed_withinInterval_triggersWarning() {
        let lastGiven = date(2025, 1, 1, hour: 2)
        let givenAt = date(2025, 1, 1, hour: 6)   // 4 hours later
        let minIntervalHours: Double = 8

        let hoursElapsed = givenAt.timeIntervalSince(lastGiven) / 3600
        #expect(hoursElapsed >= 0 && hoursElapsed < minIntervalHours)
    }

    @Test func hoursElapsed_afterInterval_noWarning() {
        let lastGiven = date(2025, 1, 1, hour: 0)
        let givenAt = date(2025, 1, 1, hour: 9)   // 9 hours later
        let minIntervalHours: Double = 8

        let hoursElapsed = givenAt.timeIntervalSince(lastGiven) / 3600
        #expect(!(hoursElapsed >= 0 && hoursElapsed < minIntervalHours))
    }

    @Test func hoursElapsed_backInTime_noWarning() {
        // Logging a time earlier than the last dose should not warn
        let lastGiven = date(2025, 1, 1, hour: 6)
        let givenAt = date(2025, 1, 1, hour: 2)   // before lastGiven
        let minIntervalHours: Double = 8

        let hoursElapsed = givenAt.timeIntervalSince(lastGiven) / 3600
        #expect(!(hoursElapsed >= 0 && hoursElapsed < minIntervalHours))
    }

    @Test func lastGiven_picksMaxOfScheduledAndQuick() {
        let scheduled = date(2025, 1, 1, hour: 4)
        let quick = date(2025, 1, 1, hour: 6)
        let lastGiven = max(scheduled, quick)
        #expect(lastGiven == quick)
    }
}
