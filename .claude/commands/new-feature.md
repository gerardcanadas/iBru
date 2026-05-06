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
- `NavigationStack` with `.inline` title, Cancel + Save toolbar items
- No `modelContext.save()` call needed — SwiftData flushes automatically

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

Now scaffold the feature the user described, following all of the above.
