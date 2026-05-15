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
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  CODE_SIGNING_ALLOWED=NO
```

Use `/build` to run the compile check. Use `/push` to commit and push.

## Tests are required with every change

Every new model, computed property, utility method, or business-logic change **must** ship with unit tests. Tests live in `iBruTests/` (`<Feature>Tests.swift`). Use `/add-tests` for guidance on the test patterns used in this project. Run tests locally before pushing.

## Architecture

### Data layer

**SwiftData** is the local store. Models live in `iBru/Models/`:
- `Baby` — root entity; owns `plans`, `illnesses`, `quickDoses`, `vaccines`, `growthRecords`, `dailyNotes` (all cascade)
- `MedicationPlan` — belongs to one `Baby`; owns `records` (cascade); many-to-many `illnesses`; key fields: `lastDoseDate` (exact end-slot timestamp), `effectiveScheduleEnd`, `overlapsSchedule(newStart:newEnd:)`
- `DoseRecord` — belongs to one `MedicationPlan`; records a single dose event
- `IllnessRecord` — belongs to one `Baby`; soft-links to `plans` (nullify on delete); owns `temperatures` (cascade)
- `QuickDoseRecord` — belongs to one `Baby`; records a one-off dose not tied to any plan
- `TemperatureReading` — belongs to one `IllnessRecord`
- `VaccineRecord` — belongs to one `Baby`
- `GrowthRecord` — belongs to one `Baby`; optional weight/height/head fields
- `DailyNote` — belongs to one `Baby`; `date` normalized to start-of-day in `init`

Every model has `var id: String = UUID().uuidString` as its first property — this is the Firestore document key used for cross-device sync.

**Firestore** mirrors every SwiftData write. All cloud data lives under:
```
families/{familyId}/babies/{id}
families/{familyId}/plans/{id}
families/{familyId}/records/{id}
families/{familyId}/illnesses/{id}
families/{familyId}/quickDoses/{id}
families/{familyId}/temperatures/{id}
families/{familyId}/vaccines/{id}
families/{familyId}/growth/{id}
families/{familyId}/notes/{id}
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

`DoseScheduler` (`Utilities/DoseScheduler.swift`) is a pure-logic `enum` — no SwiftData, no UI. It computes scheduled times for a plan on a given day, supporting four `FrequencyUnit` cases: `everyNHours`, `timesPerDay`, `specificDays`, `everyNDays`. Key behaviours:
- `scheduledTimes(for:on:calendar:)` trims slots after `plan.lastDoseDate + 60s` on the final day
- `nextSlot(for:after:)` uses `Calendar.current` internally and excludes slots that have a `.skipped` `DoseRecord`; when testing `nextSlot`, use `Calendar.current`-relative dates (not fixed UTC dates) to avoid timezone mismatches

### Xcode project

The project uses `PBXFileSystemSynchronizedRootGroup` — new files placed inside `iBru/` are automatically included in the build. **No `project.pbxproj` edit is needed when adding Swift files.**

New models must be registered in the schema array in `iBruApp.swift`:
```swift
let schema = Schema([Baby.self, MedicationPlan.self, DoseRecord.self, IllnessRecord.self,
                     QuickDoseRecord.self, TemperatureReading.self, VaccineRecord.self,
                     GrowthRecord.self, DailyNote.self, NewModel.self])
```

### Previews

`Utilities/PreviewContainer.swift` exports `previewContainer` (in-memory `ModelContainer` with sample data). Add sample instances there for every new model.

## Localization

The app supports **English** (source/fallback), **Spanish** (`es`), and **Catalan** (`ca`) via a single String Catalog at `iBru/Localizable.xcstrings` (Xcode 15+, `LOCALIZATION_PREFERS_STRING_CATALOGS = YES`).

### How language switching works

`LanguageOption` (`Utilities/LanguageOption.swift`) maps `.system / .english / .spanish / .catalan` to raw values `"system" / "en" / "es" / "ca"`. The selection is stored in `@AppStorage("ibru_language")`. On change, `FamilySettingsView` writes `["es"]` (or `["ca"]`) to `UserDefaults["AppleLanguages"]`, or removes the key for "system". iOS reads this key on launch to select the bundle locale, so a full app restart is required — a "Restart Required" alert with `exit(0)` handles this.

Appearance (light / dark / system) works analogously via `AppearanceMode` + `@AppStorage("ibru_colorScheme")`, applied with `.preferredColorScheme(...)` at `RootView`.

### String patterns

| Context | Pattern |
|---|---|
| `Text(...)`, `Button("...")`, `.navigationTitle(...)` | Plain string literal — already `LocalizedStringKey` |
| `LabeledContent("Label", value: someString)` | `value:` is verbatim — use `String(localized: "key")` |
| Model computed properties returning `String` | `String(localized: "key")` — reads `AppleLanguages` |
| Dynamic messages stored as `String` | `String(localized: "...")` at assignment site |

### Adding new strings

1. Write the English literal as normal in Swift (it doubles as the catalog key).
2. Add a matching entry in `Localizable.xcstrings` under both `es` and `ca`:

```json
"My new string" : {
  "localizations" : {
    "ca" : { "stringUnit" : { "state" : "translated", "value" : "La meva nova cadena" } },
    "es" : { "stringUnit" : { "state" : "translated", "value" : "Mi nueva cadena" } }
  }
}
```

Format specifiers: `\(Int)` → `%lld`, `\(String)` → `%@`.

Never hardcode Spanish or Catalan text in Swift source — all translations belong in the xcstrings file.

## UI Architecture

### Tab structure (4 tabs)

| # | Tab | Icon | Purpose |
|---|-----|------|---------|
| 1 | **Home** | `house.fill` | Daily medication overview + quick dose logging. Medication card tap → dose timeline for that plan. |
| 2 | **Records** | `stethoscope` | Health records hub with segment picker: **Illness \| Growth \| Vaccines \| Notes**. Replaces the old Medical History tab. |
| 3 | **Insights** | `chart.xyaxis.line` | Analytics for all health data types. |
| 4 | **Profiles** | `person.2.fill` | Baby profiles + Family Settings. |

The **Today** tab was merged into Home — tapping a medication card on the Dashboard pushes the dose timeline inline.

### Feature placement

| Feature type | Where it lives |
|---|---|
| Daily action (log dose, log quick dose) | Home tab (Dashboard area) |
| Health record (illness, growth measurement, vaccine, temperature, daily note) | Records tab — new segment in `RecordsView` |
| Analytics / charting | Insights tab |
| Baby biography or account/family settings | Profiles tab |

### Records hub pattern

New health record features (Growth, Vaccines, etc.) go in `iBru/Views/Records/<Feature>/`. Each feature adds:
1. A new case to the `RecordsSegment` enum in `RecordsView.swift`
2. A new entry in the `switch` inside `RecordsView` body
3. `<Feature>ListView`, `<Feature>DetailView`, `<Feature>FormView` in `Views/Records/<Feature>/`

Use `/new-health-record` for the full scaffolding checklist.

## SwiftData conventions

- All stored properties need explicit default values with fully-qualified names (`Date.now`, `FrequencyUnit.everyNHours`) — the `@Model` macro requires this.
- Computed properties (`isActive`, `isOngoing`, `frequencySummary`, `doseSummary`) live on the model — views must not format inline.
- `@Relationship(deleteRule: .cascade, inverse: ...)` for owned children; `@Relationship(inverse: ...)` for soft links.
- `isOngoing` uses strict day comparison: same-day end means "ended today", not "still ongoing".
- All model computed properties that return user-visible `String` must use `String(localized:)` — plain literals in `String`-returning properties are NOT localized even when displayed in `Text()`.

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
| `/new-health-record` | Scaffold a new Records-hub feature (model → Firestore → Views/Records/<Feature>/ → RecordsSegment case) |
