import Foundation

enum LanguageOption: String, CaseIterable {
    case system  = "system"
    case english = "en"
    case spanish = "es"
    case catalan = "ca"

    var label: String {
        switch self {
        case .system:  return String(localized: "System")
        case .english: return "English"
        case .spanish: return "Español"
        case .catalan: return "Català"
        }
    }
}
