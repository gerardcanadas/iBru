import SwiftUI
import SwiftData

enum RecordsSegment: String, CaseIterable {
    case illness = "Illness"
    case growth = "Growth"
    case vaccines = "Vaccines"
}

struct RecordsView: View {
    let baby: Baby?
    @State private var segment: RecordsSegment = .illness

    var body: some View {
        NavigationStack {
            if let baby {
                segmentContent(baby)
                    .safeAreaInset(edge: .top, spacing: 0) {
                        segmentPicker
                    }
            } else {
                ContentUnavailableView(
                    "No profile selected",
                    systemImage: "stethoscope",
                    description: Text("Add a baby profile in the Profiles tab")
                )
                .navigationTitle("Records")
            }
        }
    }

    private var segmentPicker: some View {
        Picker("", selection: $segment) {
            ForEach(RecordsSegment.allCases, id: \.self) { s in
                Text(LocalizedStringKey(s.rawValue)).tag(s)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    @ViewBuilder
    private func segmentContent(_ baby: Baby) -> some View {
        switch segment {
        case .illness:
            IllnessListView(baby: baby)
        case .growth:
            ContentUnavailableView(
                "Coming soon",
                systemImage: "ruler",
                description: Text("Growth tracking will let you log weight, height, and head circumference")
            )
            .navigationTitle("Growth")
        case .vaccines:
            ContentUnavailableView(
                "Coming soon",
                systemImage: "syringe",
                description: Text("Vaccine log will let you track upcoming and completed vaccines")
            )
            .navigationTitle("Vaccines")
        }
    }
}

#Preview {
    let container = previewContainer
    let baby = try! container.mainContext.fetch(FetchDescriptor<Baby>()).first!
    return RecordsView(baby: baby)
        .modelContainer(container)
}
