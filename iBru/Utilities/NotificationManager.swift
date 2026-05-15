import UserNotifications
import Foundation
import SwiftData

// Protocol allows injecting a mock center in tests.
protocol NotificationScheduling {
    func getPendingNotificationRequests(completionHandler: @escaping ([UNNotificationRequest]) -> Void)
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
    func add(_ request: UNNotificationRequest, withCompletionHandler completionHandler: ((Error?) -> Void)?)
}

extension UNUserNotificationCenter: NotificationScheduling {}

final class NotificationManager {
    static let shared = NotificationManager()

    private let center: any NotificationScheduling

    // Serial queue ensures remove+add pairs for one plan are never interleaved with
    // those of a concurrent call. Semaphore inside each block makes the getPending
    // callback synchronous with respect to the queue.
    private let schedulingQueue = DispatchQueue(label: "com.ibru.notifications.scheduling")

    private init() { self.center = UNUserNotificationCenter.current() }

    /// For unit tests — inject a mock center.
    init(center: any NotificationScheduling) { self.center = center }

    // MARK: - Permission setup

    func requestPermission() {
        let takenAction = UNNotificationAction(
            identifier: "MARK_TAKEN",
            title: "Mark as Taken",
            options: [.authenticationRequired]
        )
        let skipAction = UNNotificationAction(
            identifier: "SKIP_DOSE",
            title: "Skip",
            options: []
        )
        let category = UNNotificationCategory(
            identifier: "MEDICATION_REMINDER",
            actions: [takenAction, skipAction],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    // MARK: - Schedule

    func scheduleNotifications(for plan: MedicationPlan) {
        // If the plan has already ended or been stopped, cancel any lingering
        // notifications rather than scheduling new ones.
        guard plan.isCurrentOrFuture else {
            cancelAllNotifications(for: plan)
            return
        }

        // IMPORTANT: use plan.id (stable UUID set at init time) as the prefix.
        // plan.persistentModelID is unstable for newly-inserted objects — it changes
        // between the temporary in-memory ID and the permanent store ID after the first
        // SwiftData save, causing orphaned notifications that are never removed.
        let prefix = plan.id

        // Snapshot all plan properties on the calling (main) thread before touching
        // the background queue — MedicationPlan is a non-Sendable SwiftData model.
        let medicationName = plan.medicationName
        let doseSummary    = plan.doseSummary
        let calendar       = Calendar.current
        let now            = Date.now

        // Pre-compute slots here, on the main thread, while the model is safely accessible.
        struct SlotInfo {
            let date: Date
            // Use Int seconds for a stable, human-readable ID.
            // Double formatting of timeIntervalSince1970 can vary with subsecond precision
            // inherited from plan.startDate, producing different strings for the same
            // dose-minute and causing duplicates in the notification center.
            let id: String
        }

        let slots: [SlotInfo] = (0..<7).flatMap { offset -> [SlotInfo] in
            guard let day = calendar.date(byAdding: .day, value: offset, to: now) else { return [] }
            return DoseScheduler.scheduledTimes(for: plan, on: day, calendar: calendar)
                .filter { $0 > now }
                .map { SlotInfo(date: $0, id: "\(prefix)-\(Int($0.timeIntervalSince1970))") }
        }

        let center = self.center
        schedulingQueue.async {
            let semaphore = DispatchSemaphore(value: 0)
            center.getPendingNotificationRequests { pending in
                let oldIDs = pending
                    .filter { $0.identifier.hasPrefix(prefix) }
                    .map(\.identifier)
                center.removePendingNotificationRequests(withIdentifiers: oldIDs)

                // Use a DispatchGroup so the semaphore is only signalled after every
                // add() is acknowledged by the notification center. Without this,
                // a second scheduleNotifications() call on the serial queue can read
                // a stale pending list (missing the first call's additions) and fail
                // to remove them — producing duplicate or stale notifications.
                let group = DispatchGroup()
                for slot in slots {
                    let content = UNMutableNotificationContent()
                    content.title = medicationName
                    content.body = "Time for \(doseSummary)"
                    content.sound = .default
                    content.categoryIdentifier = "MEDICATION_REMINDER"
                    content.userInfo = [
                        "planID": prefix,
                        "slot": slot.date.timeIntervalSince1970
                    ]
                    let comps = calendar.dateComponents(
                        [.year, .month, .day, .hour, .minute], from: slot.date
                    )
                    let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                    let request = UNNotificationRequest(
                        identifier: slot.id, content: content, trigger: trigger
                    )
                    group.enter()
                    center.add(request) { _ in group.leave() }
                }
                group.notify(queue: .global(qos: .background)) {
                    semaphore.signal()
                }
            }
            semaphore.wait()
        }
    }

    /// Reschedule notifications for all active plans and cancel notifications for
    /// inactive ones. Call on app launch (after data sync) so the OS queue always
    /// reflects the current plan state — even for plans that expired since the last
    /// foreground session.
    func syncAll(plans: [MedicationPlan]) {
        for plan in plans {
            if plan.isCurrentOrFuture {
                scheduleNotifications(for: plan)
            } else {
                cancelAllNotifications(for: plan)
            }
        }
    }

    // MARK: - Cancel

    func cancelAllNotifications(for plan: MedicationPlan) {
        let prefix = plan.id
        let center = self.center
        schedulingQueue.async {
            let semaphore = DispatchSemaphore(value: 0)
            center.getPendingNotificationRequests { pending in
                let ids = pending.filter { $0.identifier.hasPrefix(prefix) }.map(\.identifier)
                center.removePendingNotificationRequests(withIdentifiers: ids)
                semaphore.signal()
            }
            semaphore.wait()
        }
    }

    func cancelAllNotifications(for baby: Baby) {
        let prefixes = baby.plans.map { $0.id }
        let center = self.center
        schedulingQueue.async {
            let semaphore = DispatchSemaphore(value: 0)
            center.getPendingNotificationRequests { pending in
                let ids = pending
                    .filter { req in prefixes.contains(where: { req.identifier.hasPrefix($0) }) }
                    .map(\.identifier)
                center.removePendingNotificationRequests(withIdentifiers: ids)
                semaphore.signal()
            }
            semaphore.wait()
        }
    }

    func cancelNotification(id: String) {
        center.removePendingNotificationRequests(withIdentifiers: [id])
    }

    // MARK: - Testing helpers

    /// Blocks until all queued scheduling/cancellation work has finished.
    /// Call this in tests immediately after scheduling to get a stable state to assert on.
    func flushForTesting() {
        schedulingQueue.sync {}
    }
}
