import SwiftUI
import SwiftData

@main
struct iBruApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(for: [Baby.self, MedicationPlan.self, DoseRecord.self]) { result in
                    if case .success(let container) = result {
                        appDelegate.modelContainer = container
                    }
                }
                .task {
                    NotificationManager.shared.requestPermission()
                }
        }
    }
}
