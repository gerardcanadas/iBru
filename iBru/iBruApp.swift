import SwiftUI
import SwiftData

@main
struct iBruApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    private let container: ModelContainer = {
        let schema = Schema([Baby.self, MedicationPlan.self, DoseRecord.self, IllnessRecord.self])
        let config = ModelConfiguration(schema: schema)
        return try! ModelContainer(for: schema, configurations: config)
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(container)
                .task {
                    appDelegate.modelContainer = container
                    NotificationManager.shared.requestPermission()
                }
        }
    }
}
