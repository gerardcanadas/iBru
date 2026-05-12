Scaffold a complete feature for this project: List view + Form view + Detail view.

## Project structure

- Files go in `iBru/Views/<FeatureName>/` — Xcode auto-discovers them, no pbxproj edit needed
- The feature is typically exposed via a new tab in `ContentView.swift` or a NavigationLink from an existing view

## Standard feature pattern

Every feature consists of three views:

### 1. ListVIew
- Accepts `baby: Baby` and `modelContext` from environment
- Two sections: ongoing/active (filtered + sorted desc) and past/ended (filtered + sorted desc)
- Each row: `NavigationLink { DetailView(record:) } label: { RowView(record:) }`
- Swipe actions: Edit (blue, `.pencil`) and Delete (destructive, `.trash`)
- Delete uses `@State private var recordToDelete` + `confirmationDialog` (NOT `.alert`) — warn the user before deleting
- Toolbar `.primaryAction` button opens add sheet
- Private `RowView` struct at bottom of same file — keeps it out of global namespace
- `ContentUnavailableView` when both sections are empty

### 2. FormView
- Accepts `baby: Baby` and optional `record: MyModel?` (nil = new, non-nil = edit)
- `private var isEditing: Bool { record != nil }`
- All form fields are `@State` vars initialized to sensible defaults
- `onAppear { loadFromRecord() }` — populates state from existing record when editing
- `private var isValid: Bool { ... }` — disables Save button
- `save()` — branches on `plan == nil` for insert vs update; calls `modelContext.insert()` for new items; SwiftData auto-saves on dismiss
- **Every insert and update must be followed by a Firestore write-through** (see pattern below)
- `NavigationStack` with `.inline` title, Cancel + Save toolbar items
- No `modelContext.save()` call needed — SwiftData flushes automatically

### Firestore write-through pattern

Every write (insert, update, delete) must mirror to Firestore so other devices see the change.

**Insert / update** — add after `modelContext.insert(r)` or after mutating an existing record:
```swift
Task { await FirestoreService.shared.save(r) }
```

**Delete** — capture the id BEFORE deleting (the object is invalid after deletion):
```swift
let id = record.id
modelContext.delete(record)
Task { await FirestoreService.shared.delete(myModelId: id) }
```

**Inline mutations** (e.g. "Mark as Recovered" button in a DetailView):
```swift
Button {
    record.endDate = .now
    Task { await FirestoreService.shared.save(record) }
} label: { ... }
```

`FirestoreService` must have matching `save(_ r: MyModel)` and `delete(myModelId:)` methods — add them following the existing patterns for `Baby`, `MedicationPlan`, etc. Use `/add-sync-for-model` to generate the full sync wiring for a new model.

### 3. DetailView
- Accepts the model directly (not just an ID)
- Sections: status/dates, linked items, notes
- Action button (e.g. "Mark as Recovered") changes a property directly on the model — SwiftData propagates the change
- If the model has `isOngoing`, show the recovery action only when `record.isOngoing`

## ForEach gotcha with SwiftData @Model inside Form/Section

`ForEach(baby.plans)` inside a `Form > Section` causes the compiler to pick the `ForEach(Binding<C>, ...)` overload instead of `RandomAccessCollection`. Fix by wrapping in a plain non-@Model struct:

```swift
private struct PlanOption: Identifiable {
    let id: PersistentIdentifier
    let name: String
}
private var planOptions: [PlanOption] {
    baby.plans.map { PlanOption(id: $0.persistentModelID, name: $0.medicationName) }
}
// Then: ForEach(planOptions) { option in ... }  ✅
```

## Adding to navigation

If adding a new tab, edit `ContentView.swift`:
```swift
Tab("Label", systemImage: "sf.symbol") {
    NavigationStack { MyListView(baby: selectedBaby) }
}
```

## Localization

The app supports English (default), Spanish, and Catalan via `iBru/Localizable.xcstrings`.

**In SwiftUI views**: `Text("Some string")`, `Button("Label")`, `Label("Title", ...)`, `.navigationTitle("X")` all accept `LocalizedStringKey` automatically — just use string literals as normal. Xcode looks up the key in `Localizable.xcstrings` at runtime.

**For string values (not LocalizedStringKey)**: Anywhere a `String` is returned or stored, use `String(localized: "key")`:
- Model computed properties (`frequencySummary`, `durationSummary`, `label` on enums)
- `LabeledContent("Label", value: someString)` — the `value:` parameter is verbatim
- Dynamic confirmation/error messages stored in `@State var message: String`

**Adding new strings**: For every new user-visible string, add a matching key to `iBru/Localizable.xcstrings` with Spanish (`es`) and Catalan (`ca`) translations. The source language is English — English entries are omitted (key = value). Format specifier keys: `\(Int)` becomes `%lld`, `\(String)` becomes `%@`.

```json
"My new string" : {
  "localizations" : {
    "ca" : { "stringUnit" : { "state" : "translated", "value" : "La meva nova cadena" } },
    "es" : { "stringUnit" : { "state" : "translated", "value" : "Mi nueva cadena" } }
  }
}
```

Never hardcode Spanish or Catalan strings in Swift source — all translations live in the xcstrings file.

Now scaffold the feature the user described, following all of the above.
