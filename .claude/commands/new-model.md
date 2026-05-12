Scaffold a new SwiftData @Model class for this project.

## Project conventions to follow

- File goes in `iBru/Models/`; Xcode auto-discovers it (PBXFileSystemSynchronizedRootGroup — no pbxproj edit needed)
- ALL stored properties must have explicit default values with fully-qualified names: `Date.now` not `.now`, enum cases as `MyEnum.value` not `.value` — this is required by SwiftData's @Model macro
- Every model needs an explicit `init()` even when all properties have defaults
- **Every model must have `var id: String = UUID().uuidString`** as its first property — this is the stable Firestore document key used for cross-device sync. Without it, sync will not work.
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

## Firestore sync

After creating the model, wire it up for cross-device sync using `/add-sync-for-model`. This adds:
- `save(_ model: NewModel)` and `delete(newModelId:)` to `FirestoreService`
- Write-through calls in every view that inserts, updates, or deletes this model
- The model in `syncAll` so it is pulled on app launch

## Example skeleton

```swift
import SwiftData
import Foundation

@Model
final class MyModel {
    var id: String = UUID().uuidString
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
        return "\(start) – \(String(localized: "ongoing"))"
    }
}
```

## Localization

All computed properties that return user-visible strings **must** use `String(localized:)` so they pick up the correct translation when the user has changed the in-app language. Plain string literals in computed properties are NOT localized.

```swift
// ✅ correct
var statusLabel: String { String(localized: "Ongoing") }

// ❌ wrong — ignores the selected language
var statusLabel: String { "Ongoing" }
```

After adding new localized keys, add matching `es` and `ca` translations in `iBru/Localizable.xcstrings`.

Now create the model the user described, following all of the above.
