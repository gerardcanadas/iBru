# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build and test commands

```bash
# Build (check for compiler errors)
xcodebuild -scheme iBru -destination 'generic/platform=iOS Simulator' build 2>&1 | grep -E "error:|BUILD"

# Run tests — do NOT pipe through grep; Swift Testing output won't match XCTest patterns
xcodebuild test \
  -project iBru.xcodeproj \
  -scheme iBru \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  CODE_SIGNING_ALLOWED=NO
```

Use `/build` to run the compile check. Use `/push` to commit and push.

## Tests are required with every change

Every new model, computed property, utility method, or business-logic change **must** ship with unit tests. Tests live in `iBruTests/` (`<Feature>Tests.swift`). Use `/add-tests` for guidance on the test patterns used in this project. Run tests locally before pushing.

## Architecture

### Data layer

**SwiftData** is the local store. Models live in `iBru/Models/`:
- `Baby` — root entity; owns `plans`, `illnesses`, and `quickDoses` (all cascade)
- `MedicationPlan` — belongs to one `Baby`; owns `records` (cascade); many-to-many `illnesses`
- `DoseRecord` — belongs to one `MedicationPlan`; records a single dose event
- `IllnessRecord` — belongs to one `Baby`; soft-links to `plans` (nullify on delete)
- `QuickDoseRecord` — belongs to one `Baby`; records a one-off dose not tied to any plan

Every model has `var id: String = UUID().uuidString` as its first property — this is the Firestore document key used for cross-device sync.

**Firestore** mirrors every SwiftData write. All cloud data lives under:
```
families/{familyId}/babies/{id}
families/{familyId}/plans/{id}
families/{familyId}/records/{id}
families/{familyId}/illnesses/{id}
families/{familyId}/quickDoses/{id}
```

### Services

- `AuthService` (`Services/AuthService.swift`) — `@Observable` singleton; wraps Firebase Auth + Google Sign-In; exposes `isSignedIn`, `userEmail`
- `FamilyService` (`Services/FamilyService.swift`) — `@Observable` singleton; stores `familyId` in `UserDefaults`; handles create/join/invite/auto-resolve; `familyRef` in `FirestoreService` uses its `familyId`
- `FirestoreService` (`Services/FirestoreService.swift`) — non-observable singleton; `save(_:)` and `delete(...Id:)` for each model; `syncAll(context:)` called on app open

### Write-through pattern

Every SwiftData mutation must mirror to Firestore immediately:
```swift
// insert or update
Task { await FirestoreService.shared.save(record) }

// delete — capture id BEFORE deletion
let id = record.id
modelContext.delete(record)
Task { await FirestoreService.shared.delete(recordId: id) }
```

### App entry and auth gate

`iBruApp` boots `RootView`, which implements a three-state gate:
1. Not signed in → `LoginView`
2. Signed in, no family → `FamilySetupView`
3. Has family → `ContentView` + triggers `FirestoreService.syncAll` via `.task(id: family.familyId)`

`AppDelegate` calls `FirebaseApp.configure()` and handles Google Sign-In URL callbacks.

### Scheduling logic

`DoseScheduler` (`Utilities/DoseScheduler.swift`) is a pure-logic `enum` — no SwiftData, no UI. It computes scheduled times for a plan on a given day, supporting four `FrequencyUnit` cases: `everyNHours`, `timesPerDay`, `specificDays`, `everyNDays`.

### Xcode project

The project uses `PBXFileSystemSynchronizedRootGroup` — new files placed inside `iBru/` are automatically included in the build. **No `project.pbxproj` edit is needed when adding Swift files.**

New models must be registered in the schema array in `iBruApp.swift`:
```swift
let schema = Schema([Baby.self, MedicationPlan.self, DoseRecord.self, IllnessRecord.self, NewModel.self])
```

### Previews

`Utilities/PreviewContainer.swift` exports `previewContainer` (in-memory `ModelContainer` with sample data). Add sample instances there for every new model.

## SwiftData conventions

- All stored properties need explicit default values with fully-qualified names (`Date.now`, `FrequencyUnit.everyNHours`) — the `@Model` macro requires this.
- Computed properties (`isActive`, `isOngoing`, `frequencySummary`, `doseSummary`) live on the model — views must not format inline.
- `@Relationship(deleteRule: .cascade, inverse: ...)` for owned children; `@Relationship(inverse: ...)` for soft links.
- `isOngoing` uses strict day comparison: same-day end means "ended today", not "still ongoing".

## Claude Code skills

Skills are in `.claude/commands/`:

| Skill | Purpose |
|---|---|
| `/build` | Real `xcodebuild` compile check |
| `/push` | Stage relevant files, commit, push to main |
| `/new-model` | Scaffold a SwiftData `@Model` with id, schema registration, preview data |
| `/new-feature` | Scaffold List + Form + Detail views with Firestore write-through |
| `/add-sync-for-model` | Wire Firestore save/delete/syncAll for an existing model |
| `/add-notifications` | Add local push notifications for a medication plan |
| `/add-preview-data` | Add sample instances to `PreviewContainer` |
| `/new-scheduler-type` | Add a new `FrequencyUnit` case end-to-end |
