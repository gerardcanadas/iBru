Add unit tests for the logic or model the user describes.

## Tests are required with every change

Every new model, computed property, utility method, or business-logic change **must** ship with corresponding tests. When implementing a feature:
1. Write the feature code.
2. Add or update a `<Feature>Tests.swift` in `iBruTests/`.
3. Run `/build` to confirm no compile errors, then run the tests locally before pushing.

If a change touches existing test coverage, update those tests too — don't leave stale assertions.

**View-level logic rule**: If a SwiftUI view contains non-trivial computation (date arithmetic, set operations, filtering, aggregation), extract it to a static method on the relevant engine (`InsightsEngine`, `DoseScheduler`, etc.) so it can be unit-tested. Private view computed properties that contain business logic are untestable and must be moved out.

## Test target setup

Tests live in `iBruTests/` (sibling of `iBru/`). The folder uses `PBXFileSystemSynchronizedRootGroup` — drop a `.swift` file in and it's automatically compiled into the `iBruTests` target. No `project.pbxproj` edits needed for new test files.

The target is a host-based unit test bundle: `BUNDLE_LOADER` and `TEST_HOST` point to the iBru app, so `@testable import iBru` gives access to all internal types.

## File structure

```
iBruTests/
  DailyNoteTests.swift          — DailyNote model (date normalisation, content, relationship)
  DoseSchedulerTests.swift      — pure-logic scheduling tests (lastDoseDate filter, nextSlot skip exclusion)
  FamilyServiceTests.swift      — FamilyService pure-state tests (no Firestore)
  GrowthRecordTests.swift       — GrowthRecord model tests
  InsightsEngineTests.swift     — InsightsEngine + calendar helper tests
  MedicationPlanTests.swift     — computed property tests (doseSummary, isActive, overlapsSchedule, etc.) + IllnessRecordTests
  NotificationManagerTests.swift — notification scheduling logic
  QuickDoseRecordTests.swift    — QuickDoseRecord model + interval warning logic
  TemperatureReadingTests.swift — TemperatureReading model tests
  VaccineRecordTests.swift      — VaccineRecord model tests
  WHOGrowthDataTests.swift      — WHO percentile table integrity tests
```

Add new test files following the `<Feature>Tests.swift` naming convention.

## Framework and imports

```swift
import Testing        // Swift Testing — use @Suite, @Test, #expect
import SwiftData      // for in-memory ModelContainer
@testable import iBru // access to internal types
```

Do NOT use XCTest. All new tests use the Swift Testing framework.

## SwiftData in tests

`@Model` classes need a live `ModelContext` before accessing properties. Use an in-memory container:

```swift
@Suite @MainActor
struct MyFeatureTests {
    var container: ModelContainer
    var context: ModelContext

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: Baby.self, MedicationPlan.self, DoseRecord.self, IllnessRecord.self,
            QuickDoseRecord.self, TemperatureReading.self, VaccineRecord.self,
            GrowthRecord.self, DailyNote.self,
            configurations: config
        )
        context = ModelContext(container)
    }
}
```

Always include the full current schema — SwiftData will throw at test startup if a model in the relationship graph is missing from the container.

Swift Testing calls `init()` before each `@Test`, so every test gets an isolated in-memory store. Mark the suite `@MainActor` — SwiftData context operations require the main actor.

## Writing tests

```swift
@Test func everyNHours_startAtMidnight_threeTimesInDay() {
    let p = makePlan(frequency: .everyNHours, value: 8, start: date(2025, 1, 1))
    let times = DoseScheduler.scheduledTimes(for: p, on: date(2025, 1, 1), calendar: utc)
    #expect(times.count == 3)
    #expect(times[0] == date(2025, 1, 1, hour: 0))
}
```

Naming convention: `<subject>_<condition>_<expectedOutcome>`.

## What to test

Good candidates:
- `DoseScheduler.scheduledTimes(for:on:calendar:)` — pure logic, easy to isolate; also `nextSlot` (use `Calendar.current`-relative dates, not UTC, since `nextSlot` uses `Calendar.current` internally)
- Model computed properties: `isActive`, `isOngoing`, `isCurrentOrFuture`, `effectiveScheduleEnd`, `overlapsSchedule`, `frequencySummary`, `doseSummary`, `durationSummary`
- `InsightsEngine` static methods: `dateRange`, `medicationInsights`, `illnessInsights`, `illnessDayIDs`, `illnessStartDayIDs`, `dayID`
- `FamilyService` pure state methods: `store`, `clearFamily`, `hasFamily`, `FamilyError`
- `WHOGrowthData` table integrity: row count, p3 < p50 < p97, interpolation bounds

Avoid testing:
- Views (no UIKit/SwiftUI test infrastructure is set up)
- `FirestoreService` calls (require live Firebase; use integration tests for that)
- `FamilyService` methods that call Firestore (`createFamily`, `joinFamily`, `fetchMembers`, etc.)
- Anything that relies on `Date.now` without injecting the date

## When a change touches view code only

If a change adds or removes code exclusively inside SwiftUI view bodies or private view methods, state this explicitly rather than silently skipping tests. Acceptable reasons to have no new tests:

- Only removed code (no new logic, no new computed properties)
- New logic is a trivial single-expression default (e.g. a one-liner filter used as a UI default) and depends on private view types that cannot be constructed in tests
- The change is a pure layout/style adjustment

If the logic is non-trivial (date arithmetic, aggregation, multi-step filtering), extract it to a static engine method first, then test it there.

## Firebase-safe service singletons

Any `@Observable` service singleton that uses Firestore **must** declare its `db` property with `@ObservationIgnored private lazy var` so initialization is deferred until the first network call. Without this, accessing the singleton during tests (where `FirebaseApp.configure()` is skipped) crashes the entire test process and fails all tests:

```swift
// BAD — crashes test process on first access
private let db = Firestore.firestore()

// GOOD — deferred until first Firestore call
@ObservationIgnored private lazy var db = Firestore.firestore()
```

When adding a new `@Observable` service that wraps Firestore, always use the lazy pattern. Tests for such services can only cover the pure state logic (properties, enums, methods that don't touch `db`).

## Locale safety for localized strings

`String(localized:)` in model computed properties reads from `Bundle.main` at runtime, which is the app bundle (not the test bundle). The active language is determined by `AppleLanguages` in `UserDefaults` — the same key the in-app language picker sets. If a developer or CI has selected a non-English language, the strings returned will be Spanish or Catalan, not English.

**Never assert an exact English localized string in tests.** Instead, assert locale-independent invariants:

| What to test | Bad (locale-dependent) | Good (locale-independent) |
|---|---|---|
| Number appears | `== "Every 8h"` | `.contains("8")` |
| Branching (special case) | `== "Daily"` | `value1result != value2result` and `!result.contains("1")` |
| Weekday symbol | `hasSuffix("Wed")` | `.contains(Calendar.current.shortWeekdaySymbols[3])` |
| "Ongoing" suffix | `hasSuffix("ongoing")` | `ongoingParts[1] != resolvedParts[1]` |
| Two-part structure | `!contains("ongoing")` | `parts.count == 2` + `!parts[0].isEmpty` |

This rule applies to any test that calls a method using `String(localized:)` internally.

## Timezone safety

When testing time-based logic, pass an explicit UTC calendar to avoid timezone flakiness in CI:

```swift
private var utc: Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "UTC")!
    return c
}
```

Pass this calendar to any engine method that accepts a `calendar:` parameter. Use containment checks (`range.contains(date)`) rather than exact bound equality when testing date ranges derived from `Calendar.current`.

## Running tests locally

```bash
xcodebuild test \
  -project iBru.xcodeproj \
  -scheme iBru \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  CODE_SIGNING_ALLOWED=NO
```

Or press ⌘U in Xcode.
