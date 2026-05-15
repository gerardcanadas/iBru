import SwiftData
import Foundation

@Model
final class DailyNote {
    var id: String = UUID().uuidString
    var date: Date = Date.now
    var content: String = ""

    var baby: Baby?
    var illness: IllnessRecord?

    init(date: Date = .now, content: String = "") {
        self.date = Calendar.current.startOfDay(for: date)
        self.content = content
    }
}
