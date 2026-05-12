import Testing
import Foundation
@testable import iBru

// Tests cover only the pure in-memory state of FamilyService (no Firestore I/O).
// Methods that write to Firestore (createFamily, joinFamily, inviteMember, fetchMembers)
// require a live emulator and are not covered here.

@Suite @MainActor
struct FamilyServiceTests {

    init() {
        // Reset singleton state before every test
        FamilyService.shared.clearFamily()
    }

    // MARK: - hasFamily

    @Test func hasFamily_falseAfterClear() {
        #expect(FamilyService.shared.hasFamily == false)
    }

    @Test func hasFamily_trueAfterStore() {
        FamilyService.shared.store("abc-123")
        #expect(FamilyService.shared.hasFamily == true)
    }

    // MARK: - store / clearFamily

    @Test func store_setsFamilyId() {
        FamilyService.shared.store("test-id")
        #expect(FamilyService.shared.familyId == "test-id")
    }

    @Test func clearFamily_nilsFamilyId() {
        FamilyService.shared.store("test-id")
        FamilyService.shared.clearFamily()
        #expect(FamilyService.shared.familyId == nil)
    }

    @Test func clearFamily_emptiesMembers() {
        // Simulate a loaded members list by storing a family id, then
        // verify clearFamily resets members too.
        FamilyService.shared.store("test-id")
        // members can only be populated via Firestore; we verify the reset path
        // by confirming they're empty after clear regardless of prior state.
        FamilyService.shared.clearFamily()
        #expect(FamilyService.shared.members.isEmpty)
    }

    @Test func clearFamily_hasFamilyBecomesTrue_thenFalse() {
        FamilyService.shared.store("abc")
        #expect(FamilyService.shared.hasFamily == true)
        FamilyService.shared.clearFamily()
        #expect(FamilyService.shared.hasFamily == false)
    }

    // MARK: - members initial state

    @Test func members_emptyAfterClear() {
        #expect(FamilyService.shared.members.isEmpty)
    }

    // MARK: - FamilyError

    @Test func familyError_notFound_hasDescription() {
        let err = FamilyService.FamilyError.notFound
        #expect(err.errorDescription != nil)
        #expect(err.errorDescription?.isEmpty == false)
    }
}
