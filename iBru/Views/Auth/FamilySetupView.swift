import SwiftUI

struct FamilySetupView: View {
    let userEmail: String

    @State private var joinCode = ""
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "person.2.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.tint)
                    Text("Set up your family")
                        .font(.title2.bold())
                    Text("Create a new group or join one with a family code.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                Spacer()
                VStack(spacing: 16) {
                    if let error {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }
                    Button { Task { await create() } } label: {
                        Group {
                            if isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text("Create a new family")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(isLoading)

                    HStack {
                        Rectangle().frame(height: 1).foregroundStyle(.separator)
                        Text("or join with a code")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize()
                            .padding(.horizontal, 8)
                        Rectangle().frame(height: 1).foregroundStyle(.separator)
                    }

                    VStack(spacing: 8) {
                        TextField("Family code", text: $joinCode)
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                        Button { Task { await join() } } label: {
                            Text("Join")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(joinCode.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
            .navigationTitle("Family Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .secondaryAction) {
                    Button("Sign out", role: .destructive) { try? AuthService.shared.signOut() }
                }
            }
        }
    }

    private func create() async {
        isLoading = true; error = nil
        do { try await FamilyService.shared.createFamily(ownerEmail: userEmail) }
        catch { self.error = error.localizedDescription }
        isLoading = false
    }

    private func join() async {
        isLoading = true; error = nil
        do {
            try await FamilyService.shared.joinFamily(
                id: joinCode.trimmingCharacters(in: .whitespaces),
                email: userEmail
            )
        } catch { self.error = error.localizedDescription }
        isLoading = false
    }
}
