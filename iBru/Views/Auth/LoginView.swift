import SwiftUI

struct LoginView: View {
    @State private var isSigningIn = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)
                Text("iBru")
                    .font(.largeTitle.bold())
                Text("Baby care for the whole family")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(spacing: 12) {
                if let error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                Button {
                    Task { await signIn() }
                } label: {
                    HStack(spacing: 10) {
                        if isSigningIn {
                            ProgressView().tint(.primary)
                        } else {
                            Image(systemName: "person.badge.key.fill")
                        }
                        Text("Sign in with Google")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(isSigningIn)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
    }

    private func signIn() async {
        isSigningIn = true
        error = nil
        do {
            try await AuthService.shared.signInWithGoogle()
        } catch {
            self.error = error.localizedDescription
        }
        isSigningIn = false
    }
}
