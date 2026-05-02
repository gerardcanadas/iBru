import UserNotifications
import Foundation

final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    func requestPermission() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func scheduleNotifications(for plan: MedicationPlan) {
        let center = UNUserNotificationCenter.current()
        let prefix = "\(plan.persistentModelID)"

        center.getPendingNotificationRequests { requests in
            let ids = requests.filter { $0.identifier.hasPrefix(prefix) }.map(\.identifier)
            center.removePendingNotificationRequests(withIdentifiers: ids)

            let calendar = Calendar.current
            let now = Date.now
            for offset in 0..<7 {
                guard let day = calendar.date(byAdding: .day, value: offset, to: now) else { continue }
                let slots = DoseScheduler.scheduledTimes(for: plan, on: day, calendar: calendar)
                for slot in slots where slot > now {
                    let content = UNMutableNotificationContent()
                    content.title = plan.medicationName
                    content.body = "Time for \(plan.doseSummary)"
                    content.sound = .default

                    let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: slot)
                    let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                    let id = "\(prefix)-\(slot.timeIntervalSince1970)"
                    let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
                    center.add(request)
                }
            }
        }
    }

    func cancelAllNotifications(for plan: MedicationPlan) {
        let center = UNUserNotificationCenter.current()
        let prefix = "\(plan.persistentModelID)"
        center.getPendingNotificationRequests { requests in
            let ids = requests.filter { $0.identifier.hasPrefix(prefix) }.map(\.identifier)
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    func cancelAllNotifications(for baby: Baby) {
        let center = UNUserNotificationCenter.current()
        let prefixes = baby.plans.map { "\($0.persistentModelID)" }
        center.getPendingNotificationRequests { requests in
            let ids = requests.filter { req in prefixes.contains(where: { req.identifier.hasPrefix($0) }) }.map(\.identifier)
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    func cancelNotification(id: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }
}
