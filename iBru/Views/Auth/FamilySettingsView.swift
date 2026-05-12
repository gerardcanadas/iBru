import SwiftUI

struct FamilySettingsView: View {
    private var family = FamilyService.shared
    private var auth = AuthService.shared

    @AppStorage("ibru_colorScheme") private var colorSchemeRaw: String = "system"
    @AppStorage("ibru_language")    private var languageRaw: String = "system"
    @State private var inviteEmail = ""
    @State private var isInviting = false
    @State private var inviteMessage: (text: String, isError: Bool)?
    @State private var showRestartAlert = false

    var body: some View {
        List {
            Section("Your account") {
                LabeledContent("Signed in as", value: auth.userEmail ?? "—")
            }

            Section("Members") {
                if family.members.isEmpty {
                    Text("Loading…")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(family.members, id: \.self) { email in
                        Label(email, systemImage: "person.circle")
                    }
                }
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

            Section("Language") {
                Picker("Language", selection: $languageRaw) {
                    ForEach(LanguageOption.allCases, id: \.rawValue) { option in
                        Text(option.label).tag(option.rawValue)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
            .onChange(of: languageRaw) { _, newValue in
                let lang = LanguageOption(rawValue: newValue) ?? .system
                if lang == .system {
                    UserDefaults.standard.removeObject(forKey: "AppleLanguages")
                } else {
                    UserDefaults.standard.set([lang.rawValue], forKey: "AppleLanguages")
                    UserDefaults.standard.synchronize()
                }
                showRestartAlert = true
            }
            .alert("Restart Required", isPresented: $showRestartAlert) {
                Button("Restart Now", role: .destructive) { exit(0) }
                Button("Later", role: .cancel) { }
            } message: {
                Text("The language will change after restarting the app.")
            }

            Section("Display") {
                Picker("Appearance", selection: $colorSchemeRaw) {
                    ForEach(AppearanceMode.allCases, id: \.rawValue) { mode in
                        Text(mode.label).tag(mode.rawValue)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section {
                Button("Sign out", role: .destructive) {
                    try? AuthService.shared.signOut()
                }
            }
        }
        .navigationTitle("Family Settings")
        .navigationBarTitleDisplayMode(.large)
        .task { await FamilyService.shared.fetchMembers() }
    }

    private func invite() async {
        let email = inviteEmail.trimmingCharacters(in: .whitespaces)
        isInviting = true; inviteMessage = nil
        do {
            try await FamilyService.shared.inviteMember(email: email)
            inviteEmail = ""
            inviteMessage = (String(localized: "Invitation sent to \(email)."), false)
        } catch {
            inviteMessage = (error.localizedDescription, true)
        }
        isInviting = false
    }
}
