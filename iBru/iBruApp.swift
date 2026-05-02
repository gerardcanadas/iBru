import SwiftUI
import SwiftData

@main
struct iBruApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(for: [Baby.self, MedicationPlan.self, DoseRecord.self])
                .task {
                    NotificationManager.shared.requestPermission()
                }
        }
    }
}
