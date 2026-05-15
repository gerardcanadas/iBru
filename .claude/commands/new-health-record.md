Scaffold a new health record feature inside the Records hub.

Use this skill for features that belong in the **Records tab** — illness episodes, growth measurements, vaccines, temperature readings, and any future health record type.

## Checklist

### 1. Create the model

File: `iBru/Models/<Feature>Record.swift`

Follow `/new-model` conventions:
- `var id: String = UUID().uuidString` as first property
- Explicit default values with fully-qualified names
- Computed properties for display strings (`durationSummary`, `isOngoing`, etc.)
- `isOngoing` uses strict day comparison (same-day end = "ended today")
- All user-visible strings use `String(localized:)`

### 2. Register in schema

Add the new model to the schema array in `iBruApp.swift`:
```swift
let schema = Schema([Baby.self, MedicationPlan.self, DoseRecord.self, IllnessRecord.self,
                     QuickDoseRecord.self, TemperatureReading.self, VaccineRecord.self,
                     GrowthRecord.self, DailyNote.self, FeatureRecord.self])
```

Also add it to the in-memory container in every test file that exercises it:
```swift
container = try ModelContainer(
    for: Baby.self, MedicationPlan.self, DoseRecord.self, IllnessRecord.self,
    QuickDoseRecord.self, TemperatureReading.self, VaccineRecord.self,
    GrowthRecord.self, DailyNote.self, FeatureRecord.self,
    configurations: config
)
```

### 3. Wire Firestore sync

Use `/add-sync-for-model` to add:
- `save(_ r: FeatureRecord)` to `FirestoreService`
- `delete(featureRecordId:)` to `FirestoreService`
- The model to `syncAll(context:)` so it is pulled on app launch

Firestore path follows the pattern: `families/{familyId}/featureRecords/{id}`

### 4. Create views

Files go in `iBru/Views/Records/<Feature>/`:

```
iBru/Views/Records/<Feature>/
  <Feature>ListView.swift      — two sections: active/ongoing + past/ended
  <Feature>DetailView.swift    — status, dates, linked items, notes, action buttons
  <Feature>FormView.swift      — add/edit form with Firestore write-through
```

Follow the standard feature pattern from `/new-feature`:
- `ListView`: two sections, swipe-to-edit/delete, `confirmationDialog` for delete, `ContentUnavailableView` when empty
- `FormView`: `record: FeatureRecord?` (nil = new), `isEditing`, `isValid`, write-through after every mutation
- `DetailView`: action button (e.g. "Mark as Recovered") only shown when `record.isOngoing`

### 5. Add a RecordsSegment case

In `iBru/Views/Records/RecordsView.swift`:

1. Add a case to the `RecordsSegment` enum (currently has illness, growth, vaccines, notes):
```swift
enum RecordsSegment: String, CaseIterable {
    case illness = "Illness"
    case growth = "Growth"
    case vaccines = "Vaccines"
    case notes = "Notes"
    case feature = "Feature"   // ← new
}
```

2. Add a branch to the `switch` in the view body:
```swift
case .feature:
    FeatureListView(baby: baby)
```

3. The segment picker width is currently 360pt. If adding a fifth tab makes it too crowded, increase it or consider a navigation-based approach instead.

4. Add the tab label string to `Localizable.xcstrings` (es + ca translations).

### 6. Add preview data

Use `/add-preview-data` to add 2–3 sample `FeatureRecord` instances to `Utilities/PreviewContainer.swift`. Include at least one ongoing and one resolved record.

### 7. Add localization strings

For every new user-visible string, add `es` and `ca` translations to `iBru/Localizable.xcstrings`. Format specifiers: `\(Int)` → `%lld`, `\(String)` → `%@`.

### 8. Write tests

Create `iBruTests/<Feature>RecordTests.swift`. Test:
- Model computed properties (`isOngoing`, `durationSummary`, etc.)
- Any engine/utility logic extracted from views
- Never assert exact localized strings — use locale-independent invariants (see `/add-tests`)

## Current RecordsView state

`RecordsView` already has four segments: Illness, Growth, Vaccines, Notes. The picker is 360pt wide and lives in `.toolbar { ToolbarItem(placement: .principal) }`. The pattern to follow:

```swift
enum RecordsSegment: String, CaseIterable {
    case illness = "Illness"
    case growth = "Growth"
    case vaccines = "Vaccines"
    case notes = "Notes"
    // add new case here
}

// In segmentContent(_:):
switch segment {
case .illness:  IllnessListView(baby: baby)
case .growth:   GrowthListView(baby: baby)
case .vaccines: VaccineListView(baby: baby)
case .notes:    NoteListView(baby: baby)
// add new case here
}
```

Now scaffold the health record feature the user described, following all of the above steps.
