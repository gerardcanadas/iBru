import SwiftData
import Foundation

enum DoseStatus: String, Codable {
    case taken
    case skipped
}

@Model
final class DoseRecord {
    var scheduledDate: Date
    var recordedDate: Date
    var status: DoseStatus

    var plan: MedicationPlan?

    init(scheduledDate: Date, recordedDate: Date = .now, status: DoseStatus = .taken) {
        self.scheduledDate = scheduledDate
        self.recordedDate = recordedDate
        self.status = status
    }
}
