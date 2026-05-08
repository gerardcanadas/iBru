import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import Observation
import UIKit

@Observable
final class AuthService {
    static let shared = AuthService()

    private(set) var user: User?

    private var listenerHandle: AuthStateDidChangeListenerHandle?

    private init() {
        user = Auth.auth().currentUser
        listenerHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async { self?.user = user }
        }
    }

    var isSignedIn: Bool { user != nil }
    var userEmail: String? { user?.email }

    func signInWithGoogle() async throws {
        guard let clientID = FirebaseApp.app()?.options.clientID else { return }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return }
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)
        let credential = GoogleAuthProvider.credential(
            withIDToken: result.user.idToken!.tokenString,
            accessToken: result.user.accessToken.tokenString
        )
        try await Auth.auth().signIn(with: credential)
    }

    func signOut() throws {
        try Auth.auth().signOut()
        GIDSignIn.sharedInstance.signOut()
        FamilyService.shared.clearFamily()
    }
}
