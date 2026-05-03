import SwiftUI

struct MedicalHistoryView: View {
    let baby: Baby?

    var body: some View {
        NavigationStack {
            if let baby {
                IllnessListView(baby: baby)
            } else {
                ContentUnavailableView(
                    "No profile selected",
                    systemImage: "stethoscope",
                    description: Text("Add a baby profile in the Profiles tab")
                )
                .navigationTitle("Medical History")
            }
        }
    }
}
