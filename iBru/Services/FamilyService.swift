import FirebaseFirestore
import Observation

@Observable
final class FamilyService {
    static let shared = FamilyService()

    private(set) var familyId: String?

    private let db = Firestore.firestore()
    private let key = "ibru_familyId"

    private init() {
        familyId = UserDefaults.standard.string(forKey: key)
    }

    var hasFamily: Bool { familyId != nil }

    func createFamily(ownerEmail: String) async throws {
        let id = UUID().uuidString
        try await db.collection("families").document(id).setData([
            "ownerEmail": ownerEmail,
            "members": [ownerEmail]
        ])
        store(id)
    }

    func joinFamily(id: String, email: String) async throws {
        let doc = try await db.collection("families").document(id).getDocument()
        guard doc.exists else { throw FamilyError.notFound }
        try await db.collection("families").document(id).updateData([
            "members": FieldValue.arrayUnion([email])
        ])
        store(id)
    }

    func inviteMember(email: String) async throws {
        guard let fid = familyId else { return }
        try await db.collection("families").document(fid).updateData([
            "members": FieldValue.arrayUnion([email])
        ])
    }

    // Auto-join if the user's email is already in a family's members list
    func resolveFamily(for email: String) async {
        guard familyId == nil else { return }
        let snap = try? await db.collection("families")
            .whereField("members", arrayContains: email)
            .limit(to: 1)
            .getDocuments()
        if let fid = snap?.documents.first?.documentID {
            store(fid)
        }
    }

    func clearFamily() {
        familyId = nil
        UserDefaults.standard.removeObject(forKey: key)
    }

    func store(_ id: String) {
        familyId = id
        UserDefaults.standard.set(id, forKey: key)
    }

    enum FamilyError: LocalizedError {
        case notFound
        var errorDescription: String? { "Family not found. Check the code and try again." }
    }
}
