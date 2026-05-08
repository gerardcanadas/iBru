import UIKit
import UserNotifications
import SwiftData
import FirebaseCore
import GoogleSignIn

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    var modelContainer: ModelContainer?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }
        let info = response.notification.request.content.userInfo

        guard
            let planIDString = info["planID"] as? String,
            let slotInterval = info["slot"] as? Double,
            let container = modelContainer
        else { return }

        let actionID = response.actionIdentifier
        guard actionID == "MARK_TAKEN" || actionID == "SKIP_DOSE" else { return }

        let slot = Date(timeIntervalSince1970: slotInterval)
        let status: DoseStatus = (actionID == "MARK_TAKEN") ? .taken : .skipped

        let context = ModelContext(container)
        guard
            let plans = try? context.fetch(FetchDescriptor<MedicationPlan>()),
            let plan = plans.first(where: { "\($0.persistentModelID)" == planIDString })
        else { return }

        guard DoseScheduler.record(for: slot, in: plan) == nil else { return }

        let record = DoseRecord(scheduledDate: slot, status: status)
        record.plan = plan
        context.insert(record)
        try? context.save()
        Task { await FirestoreService.shared.save(record) }
    }
}
