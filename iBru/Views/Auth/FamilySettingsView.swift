import SwiftUI

struct FamilySettingsView: View {
    private var family = FamilyService.shared
    private var auth = AuthService.shared

    @State private var inviteEmail = ""
    @State private var isInviting = false
    @State private var inviteMessage: (text: String, isError: Bool)?

    var body: some View {
        List {
            Section("Your account") {
                LabeledContent("Signed in as", value: auth.userEmail ?? "—")
            }

            Section {
                LabeledContent("Family code", value: family.familyId ?? "—")
                Button {
                    UIPasteboard.general.string = family.familyId
                } label: {
                    Label("Copy family code", systemImage: "doc.on.doc")
                }
            } header: {
                Text("Family")
            } footer: {
                Text("Share this code with family members so they can join from the Family Setup screen.")
            }

            Section {
                TextField("email@example.com", text: $inviteEmail)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                if let msg = inviteMessage {
                    Text(msg.text)
                        .font(.caption)
                        .foregroundStyle(msg.isError ? .red : .green)
                }
                Button { Task { await invite() } } label: {
                    if isInviting {
                        ProgressView()
                    } else {
                        Text("Send invite")
                    }
                }
                .disabled(inviteEmail.trimmingCharacters(in: .whitespaces).isEmpty || isInviting)
            } header: {
                Text("Invite by email")
            } footer: {
                Text("The person must sign in with this Google account and they'll automatically join your family.")
            }

            Section {
                Button("Sign out", role: .destructive) {
                    try? AuthService.shared.signOut()
                }
            }
        }
        .navigationTitle("Family Settings")
        .navigationBarTitleDisplayMode(.large)
    }

    private func invite() async {
        let email = inviteEmail.trimmingCharacters(in: .whitespaces)
        isInviting = true; inviteMessage = nil
        do {
            try await FamilyService.shared.inviteMember(email: email)
            inviteEmail = ""
            inviteMessage = ("Invitation sent to \(email).", false)
        } catch {
            inviteMessage = (error.localizedDescription, true)
        }
        isInviting = false
    }
}
