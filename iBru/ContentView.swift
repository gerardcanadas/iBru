import SwiftUI
import SwiftData

struct ContentView: View {
    @Query(sort: \Baby.name) private var babies: [Baby]
    @State private var selectedBaby: Baby?
    @State private var selectedTab: Int = 0

    var activeBaby: Baby? { selectedBaby ?? babies.first }

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView(baby: activeBaby)
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)

            RecordsView(baby: activeBaby)
                .tabItem { Label("Records", systemImage: "stethoscope") }
                .tag(1)

            InsightsView(baby: activeBaby)
                .tabItem { Label("Insights", systemImage: "chart.xyaxis.line") }
                .tag(2)

            BabyListView(selectedBaby: $selectedBaby)
                .tabItem { Label("Profiles", systemImage: "person.2.fill") }
                .tag(3)
        }
        .onChange(of: babies) { _, newBabies in
            if selectedBaby == nil || !newBabies.contains(where: { $0.persistentModelID == selectedBaby?.persistentModelID }) {
                selectedBaby = newBabies.first
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(previewContainer)
}
