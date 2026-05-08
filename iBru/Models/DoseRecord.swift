import SwiftData
import Foundation

enum DoseStatus: String, Codable {
    case taken
    case skipped
}

@Model
final class DoseRecord {
    var id: String = UUID().uuidString
    var scheduledDate: Date = Date.now
    var recordedDate: Date = Date.now
    var status: DoseStatus = DoseStatus.taken

    var plan: MedicationPlan?

    init(scheduledDate: Date, recordedDate: Date = .now, status: DoseStatus = .taken) {
        self.scheduledDate = scheduledDate
        self.recordedDate = recordedDate
        self.status = status
    }
}
