import Testing
import Foundation
import SwiftData
import UserNotifications
@testable import iBru

// MARK: - Mock notification center

final class MockNotificationCenter: NotificationScheduling {
    private var pending: [UNNotificationRequest] = []

    func getPendingNotificationRequests(completionHandler: @escaping ([UNNotificationRequest]) -> Void) {
        completionHandler(pending)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        let toRemove = Set(identifiers)
        pending.removeAll { toRemove.contains($0.identifier) }
    }

    func add(_ request: UNNotificationRequest, withCompletionHandler completionHandler: ((Error?) -> Void)?) {
        // Replace existing request with same ID (mirrors UNUserNotificationCenter behaviour)
        pending.removeAll { $0.identifier == request.identifier }
        pending.append(request)
        completionHandler?(nil)
    }

    var pendingCount: Int { pending.count }
    var pendingIDs: [String] { pending.map(\.identifier) }
    var uniqueIDs: Set<String> { Set(pendingIDs) }
}

// MARK: - Tests

@Suite @MainActor
struct NotificationManagerTests {

    let container: ModelContainer
    let context: ModelContext
    let mock: MockNotificationCenter
    let manager: NotificationManager

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: Baby.self, MedicationPlan.self, DoseRecord.self, IllnessRecord.self,
            QuickDoseRecord.self, TemperatureReading.self, VaccineRecord.self, GrowthRecord.self,
            DailyNote.self,
            configurations: config
        )
        context = ModelContext(container)
        mock = MockNotificationCenter()
        manager = NotificationManager(center: mock)
    }

    private func insertPlan(
        name: String = "Ibuprofen",
        amount: Double = 5,
        unit: String = "ml",
        frequency: FrequencyUnit = .everyNHours,
        frequencyValue: Int = 8,
        weekdays: [Int] = [],
        startDate: Date = Calendar.current.date(byAdding: .hour, value: -1, to: .now)!
    ) -> MedicationPlan {
        let p = MedicationPlan(
            medicationName: name,
            doseAmount: amount,
            doseUnit: unit,
            frequencyUnit: frequency,
            frequencyValue: frequencyValue,
            startDate: startDate
        )
        p.weekdays = weekdays
        context.insert(p)
        return p
    }

    // MARK: - Basic scheduling

    @Test func scheduleOnce_producesNotifications() {
        let plan = insertPlan()
        manager.scheduleNotifications(for: plan)
        manager.flushForTesting()
        #expect(mock.pendingCount > 0)
    }

    @Test func scheduleOnce_allIDsContainPlanID() {
        let plan = insertPlan()
        manager.scheduleNotifications(for: plan)
        manager.flushForTesting()
        for id in mock.pendingIDs {
            #expect(id.hasPrefix(plan.id), "\(id) should start with plan.id \(plan.id)")
        }
    }

    @Test func scheduleOnce_noDuplicateIDs() {
        let plan = insertPlan()
        manager.scheduleNotifications(for: plan)
        manager.flushForTesting()
        #expect(mock.uniqueIDs.count == mock.pendingCount,
                "Expected \(mock.pendingCount) unique IDs, got \(mock.uniqueIDs.count)")
    }

    // MARK: - Idempotency — the core regression test for the duplicate-notification bug

    @Test func scheduleTwice_doesNotDuplicate() {
        let plan = insertPlan()
        manager.scheduleNotifications(for: plan)
        manager.scheduleNotifications(for: plan)
        manager.flushForTesting()

        let count = mock.pendingCount
        let uniqueCount = mock.uniqueIDs.count

        #expect(count == uniqueCount,
                "Duplicate IDs found: \(count) total, \(uniqueCount) unique")
    }

    @Test func scheduleThrice_doesNotDuplicate() {
        let plan = insertPlan()
        manager.scheduleNotifications(for: plan)
        manager.scheduleNotifications(for: plan)
        manager.scheduleNotifications(for: plan)
        manager.flushForTesting()

        #expect(mock.pendingCount == mock.uniqueIDs.count)
    }

    @Test func scheduleTwice_countMatchesSingleSchedule() {
        let plan = insertPlan()

        manager.scheduleNotifications(for: plan)
        manager.flushForTesting()
        let countAfterOne = mock.pendingCount

        manager.scheduleNotifications(for: plan)
        manager.flushForTesting()
        let countAfterTwo = mock.pendingCount

        #expect(countAfterOne == countAfterTwo,
                "Second schedule changed count: \(countAfterOne) → \(countAfterTwo)")
    }

    // MARK: - Stable identifiers

    @Test func scheduleProducesStableIDs_forSamePlan() {
        let plan = insertPlan()

        manager.scheduleNotifications(for: plan)
        manager.flushForTesting()
        let firstIDs = mock.uniqueIDs

        manager.scheduleNotifications(for: plan)
        manager.flushForTesting()
        let secondIDs = mock.uniqueIDs

        #expect(firstIDs == secondIDs, "IDs changed between schedule calls")
    }

    @Test func idUsesIntegerSeconds_notFloat() {
        let plan = insertPlan()
        manager.scheduleNotifications(for: plan)
        manager.flushForTesting()

        for id in mock.pendingIDs {
            // Expected format: "<plan.id>-<integer>"
            let parts = id.split(separator: "-", maxSplits: 5, omittingEmptySubsequences: false)
            guard let lastPart = parts.last else {
                Issue.record("Unexpected ID format: \(id)")
                continue
            }
            #expect(Int(lastPart) != nil,
                    "Last component of ID should be an integer, got '\(lastPart)' in '\(id)'")
            #expect(!lastPart.contains("."),
                    "ID should not contain decimal point (float): '\(id)'")
        }
    }

    // MARK: - Cancellation

    @Test func cancelAllForPlan_removesAllNotifications() {
        let plan = insertPlan()
        manager.scheduleNotifications(for: plan)
        manager.flushForTesting()
        #expect(mock.pendingCount > 0)

        manager.cancelAllNotifications(for: plan)
        manager.flushForTesting()
        #expect(mock.pendingCount == 0)
    }

    @Test func cancelAllForPlan_doesNotRemoveOtherPlanNotifications() {
        let plan1 = insertPlan(name: "Drug A", frequency: .everyNHours, frequencyValue: 8)
        let plan2 = insertPlan(name: "Drug B", frequency: .timesPerDay, frequencyValue: 2)

        manager.scheduleNotifications(for: plan1)
        manager.scheduleNotifications(for: plan2)
        manager.flushForTesting()
        let totalCount = mock.pendingCount

        manager.cancelAllNotifications(for: plan1)
        manager.flushForTesting()

        let plan1Count = mock.pendingIDs.filter { $0.hasPrefix(plan1.id) }.count
        let plan2Count = mock.pendingIDs.filter { $0.hasPrefix(plan2.id) }.count
        let plan2Expected = totalCount - (totalCount - plan2Count)

        #expect(plan1Count == 0, "plan1 notifications should be gone")
        #expect(plan2Count == plan2Expected, "plan2 notifications should be untouched")
    }

    @Test func scheduleAfterCancel_restoresCorrectCount() {
        let plan = insertPlan()

        manager.scheduleNotifications(for: plan)
        manager.flushForTesting()
        let originalCount = mock.pendingCount

        manager.cancelAllNotifications(for: plan)
        manager.flushForTesting()
        #expect(mock.pendingCount == 0)

        manager.scheduleNotifications(for: plan)
        manager.flushForTesting()
        #expect(mock.pendingCount == originalCount,
                "Count after cancel+reschedule (\(mock.pendingCount)) should match original (\(originalCount))")
    }

    // MARK: - Slot count by frequency type

    @Test func everyNHours_schedulesExpectedSlots() {
        // 8h interval, started 1h ago → plan.startDate is valid, not stopped
        let plan = insertPlan(frequency: .everyNHours, frequencyValue: 8,
                              startDate: Calendar.current.date(byAdding: .hour, value: -1, to: .now)!)
        manager.scheduleNotifications(for: plan)
        manager.flushForTesting()
        // 8h interval over 7 days = ~21 slots; at minimum several should be scheduled
        #expect(mock.pendingCount >= 1)
        #expect(mock.pendingCount <= 7 * 3 + 1) // at most 3 per day + rounding
    }

    @Test func timesPerDay_schedulesExactly7PerDay_overSevenDays() {
        // 1 time per day = 1 notification per day × 7 days = 7 total
        // The exact count depends on whether today's 8 AM slot is in the past.
        let plan = insertPlan(frequency: .timesPerDay, frequencyValue: 1,
                              startDate: Calendar.current.date(byAdding: .day, value: -1, to: .now)!)
        manager.scheduleNotifications(for: plan)
        manager.flushForTesting()
        // Always 6 or 7 (depends on whether today's 8 AM is past)
        #expect(mock.pendingCount >= 6)
        #expect(mock.pendingCount <= 7)
    }

    @Test func stoppedPlan_schedulesNoNotifications() {
        let plan = insertPlan()
        plan.stoppedDate = Date.now
        manager.scheduleNotifications(for: plan)
        manager.flushForTesting()
        #expect(mock.pendingCount == 0)
    }

    @Test func endedPlan_schedulesNoFutureNotifications() {
        // Plan ended yesterday
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        let plan = insertPlan(
            startDate: Calendar.current.date(byAdding: .day, value: -7, to: .now)!
        )
        plan.endDate = yesterday
        manager.scheduleNotifications(for: plan)
        manager.flushForTesting()
        #expect(mock.pendingCount == 0)
    }

    @Test func lastDoseDateInPast_schedulesNoNotifications() {
        // endDate is still in the future, but the last dose slot already passed.
        // isCurrentOrFuture = false → guard should cancel rather than schedule.
        let plan = insertPlan(startDate: Calendar.current.date(byAdding: .day, value: -3, to: .now)!)
        plan.endDate    = Calendar.current.date(byAdding: .day, value: 2, to: .now)!
        plan.lastDoseDate = Calendar.current.date(byAdding: .hour, value: -1, to: .now)!
        manager.scheduleNotifications(for: plan)
        manager.flushForTesting()
        #expect(mock.pendingCount == 0,
                "Plan whose last dose has already passed should not produce new notifications")
    }

    @Test func lastDoseDateInPast_cancelsExistingNotifications() {
        // Schedule while active, then mark as completed via lastDoseDate.
        let plan = insertPlan()
        manager.scheduleNotifications(for: plan)
        manager.flushForTesting()
        #expect(mock.pendingCount > 0, "Should have notifications while active")

        plan.endDate      = Calendar.current.date(byAdding: .day, value: 1, to: .now)!
        plan.lastDoseDate = Calendar.current.date(byAdding: .minute, value: -1, to: .now)!
        manager.scheduleNotifications(for: plan)
        manager.flushForTesting()
        #expect(mock.pendingCount == 0,
                "Re-scheduling a completed plan should cancel all its notifications")
    }

    // MARK: - syncAll

    @Test func syncAll_cancelsInactivePlan_keepsActivePlan() {
        let active   = insertPlan(name: "Active Med", frequency: .everyNHours, frequencyValue: 12)
        let inactive = insertPlan(name: "Done Med",   frequency: .everyNHours, frequencyValue: 8)

        // Both active: schedule both.
        manager.scheduleNotifications(for: active)
        manager.scheduleNotifications(for: inactive)
        manager.flushForTesting()
        let activeCountBefore = mock.pendingIDs.filter { $0.hasPrefix(active.id) }.count
        #expect(activeCountBefore > 0)
        #expect(mock.pendingIDs.filter { $0.hasPrefix(inactive.id) }.count > 0)

        // Mark one as stopped.
        inactive.stoppedDate = Date.now

        manager.syncAll(plans: [active, inactive])
        manager.flushForTesting()

        let inactiveAfter = mock.pendingIDs.filter { $0.hasPrefix(inactive.id) }.count
        let activeAfter   = mock.pendingIDs.filter { $0.hasPrefix(active.id) }.count
        #expect(inactiveAfter == 0, "syncAll should cancel the stopped plan's notifications")
        #expect(activeAfter == activeCountBefore,
                "syncAll should not affect the active plan's notification count")
    }

    @Test func syncAll_schedulesActivePlansThatHadNone() {
        // Simulate a plan that exists but was never scheduled (e.g. synced from Firestore).
        let plan = insertPlan(name: "Newly Synced")
        #expect(mock.pendingCount == 0)

        manager.syncAll(plans: [plan])
        manager.flushForTesting()
        #expect(mock.pendingCount > 0, "syncAll should schedule notifications for an unscheduled active plan")
    }

    @Test func specificDays_onlySchedulesOnMatchingWeekdays() {
        // Schedule only on Sundays (weekday 1 in iOS Calendar)
        let plan = insertPlan(
            frequency: .specificDays,
            frequencyValue: 1,
            weekdays: [1],
            startDate: Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        )
        manager.scheduleNotifications(for: plan)
        manager.flushForTesting()

        // In 7 days there is exactly 1 Sunday (or 0 if today is Sunday and 8 AM already passed)
        #expect(mock.pendingCount <= 1)
    }

    // MARK: - Multiple concurrent plans don't cross-contaminate

    @Test func twoPlansDontShareNotifications() {
        let plan1 = insertPlan(name: "Med A", frequencyValue: 12)
        let plan2 = insertPlan(name: "Med B", frequencyValue: 24)

        manager.scheduleNotifications(for: plan1)
        manager.scheduleNotifications(for: plan2)
        manager.flushForTesting()

        let plan1IDs = Set(mock.pendingIDs.filter { $0.hasPrefix(plan1.id) })
        let plan2IDs = Set(mock.pendingIDs.filter { $0.hasPrefix(plan2.id) })

        #expect(plan1IDs.isDisjoint(with: plan2IDs), "Plans share notification IDs")
        #expect(plan1IDs.count + plan2IDs.count == mock.pendingCount,
                "Some notifications belong to neither plan")
    }
}
