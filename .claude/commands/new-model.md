Scaffold a new SwiftData @Model class for this project.

## Project conventions to follow

- File goes in `iBru/Models/`; Xcode auto-discovers it (PBXFileSystemSynchronizedRootGroup — no pbxproj edit needed)
- ALL stored properties must have explicit default values with fully-qualified names: `Date.now` not `.now`, enum cases as `MyEnum.value` not `.value` — this is required by SwiftData's @Model macro
- Every model needs an explicit `init()` even when all properties have defaults
- Use `@Relationship(deleteRule: .cascade, inverse: \OtherModel.plan)` for child collections; use `@Relationship(inverse: \OtherModel.plans)` for soft links (many-to-many, nullify on delete)
- Parent back-references (`var baby: Baby?`) have no attribute — they're inferred from the parent's @Relationship
- Add computed properties for display strings (e.g. `durationSummary`, `isActive`, `frequencySummary`) — views rely on these rather than formatting inline
- If the model has an `endDate`, add `var isOngoing: Bool` that compares `endDay > today` (strictly greater — same-day end means "ended today", not "still ongoing")

## Schema registration

After creating the model, add it to the schema array in `iBruApp.swift`:
```swift
let schema = Schema([Baby.self, MedicationPlan.self, DoseRecord.self, IllnessRecord.self, NewModel.self])
```

Also add sample data for it in `Utilities/PreviewContainer.swift` so #Preview blocks work.

## Example skeleton

```swift
import SwiftData
import Foundation

@Model
final class MyModel {
    var title: String = ""
    var startDate: Date = Date.now
    var endDate: Date?
    var notes: String = ""

    var baby: Baby?

    init(title: String = "", startDate: Date = .now, endDate: Date? = nil, notes: String = "") {
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.notes = notes
    }

    var isOngoing: Bool {
        guard let end = endDate else { return true }
        let today = Calendar.current.startOfDay(for: .now)
        let endDay = Calendar.current.startOfDay(for: end)
        return endDay > today
    }

    var durationSummary: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let start = formatter.string(from: startDate)
        if let end = endDate { return "\(start) – \(formatter.string(from: end))" }
        return "\(start) – ongoing"
    }
}
```

Now create the model the user described, following all of the above.
