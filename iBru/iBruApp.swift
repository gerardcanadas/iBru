import SwiftUI
import SwiftData

@main
struct iBruApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    private let isTesting = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    private let container: ModelContainer = {
        let schema = Schema([Baby.self, MedicationPlan.self, DoseRecord.self, IllnessRecord.self, QuickDoseRecord.self])
        let config = ModelConfiguration(schema: schema)
        return try! ModelContainer(for: schema, configurations: config)
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
