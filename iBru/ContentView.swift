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
                .tabItem { Label("Dashboard", systemImage: "heart.text.square.fill") }
                .tag(0)

            TodayView(baby: activeBaby)
                .tabItem { Label("Today", systemImage: "list.bullet.clipboard.fill") }
                .tag(1)

            BabyListView(selectedBaby: $selectedBaby)
                .tabItem { Label("Profiles", systemImage: "person.2.fill") }
                .tag(2)
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
