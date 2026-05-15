import SwiftUI
import SwiftData

@main
struct iBruApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    private let isTesting = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    private static let schema = Schema([
        Baby.self, MedicationPlan.self, DoseRecord.self, IllnessRecord.self,
        QuickDoseRecord.self, TemperatureReading.self, VaccineRecord.self,
        GrowthRecord.self, DailyNote.self
    ])

    private let container: ModelContainer = {
        let config = ModelConfiguration(schema: iBruApp.schema)
        if let container = try? ModelContainer(for: iBruApp.schema, configurations: config) {
            return container
        }
        // Lightweight migration failed (schema changed incompatibly).
        // Wipe the local store — Firestore sync will restore all data on next launch.
        let fm = FileManager.default
        if let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first,
           let files = try? fm.contentsOfDirectory(at: appSupport, includingPropertiesForKeys: nil) {
            for file in files where file.pathExtension == "sqlite"
                                 || file.lastPathComponent.hasSuffix(".sqlite-wal")
                                 || file.lastPathComponent.hasSuffix(".sqlite-shm") {
                try? fm.removeItem(at: file)
            }
        }
        return try! ModelContainer(for: iBruApp.schema, configurations: config)
    }()

    var body: some Scene {
        WindowGroup {
            if !isTesting {
                RootView()
                    .modelContainer(container)
                    .task {
                        appDelegate.modelContainer = container
                        NotificationManager.shared.requestPermission()
                    }
            }
        }
    }
}

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    private var auth = AuthService.shared
    private var family = FamilyService.shared
    @State private var isResolvingFamily = false
    @AppStorage("ibru_colorScheme") private var colorSchemeRaw: String = "system"

    var body: some View {
        Group {
            if !auth.isSignedIn {
                LoginView()
            } else if isResolvingFamily {
                ProgressView("Checking family…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !family.hasFamily {
                FamilySetupView(userEmail: auth.userEmail ?? "")
            } else {
                ContentView()
                    .task(id: family.familyId) {
                        await FirestoreService.shared.syncAll(context: modelContext)
                        let plans = (try? modelContext.fetch(FetchDescriptor<MedicationPlan>())) ?? []
                        NotificationManager.shared.syncAll(plans: plans)
                    }
            }
        }
        .preferredColorScheme(AppearanceMode(rawValue: colorSchemeRaw)?.colorScheme ?? nil)
        .task(id: auth.userEmail) {
            guard let email = auth.userEmail, !family.hasFamily else { return }
            isResolvingFamily = true
            await FamilyService.shared.resolveFamily(for: email)
            isResolvingFamily = false
        }
    }
}
