Add unit tests for the logic or model the user describes.

## Tests are required with every change

Every new model, computed property, utility method, or business-logic change **must** ship with corresponding tests. When implementing a feature:
1. Write the feature code.
2. Add or update a `<Feature>Tests.swift` in `iBruTests/`.
3. Run `/build` to confirm no compile errors, then run the tests locally before pushing.

If a change touches existing test coverage, update those tests too — don't leave stale assertions.

## Test target setup

Tests live in `iBruTests/` (sibling of `iBru/`). The folder uses `PBXFileSystemSynchronizedRootGroup` — drop a `.swift` file in and it's automatically compiled into the `iBruTests` target. No `project.pbxproj` edits needed for new test files.

The target is a host-based unit test bundle: `BUNDLE_LOADER` and `TEST_HOST` point to the iBru app, so `@testable import iBru` gives access to all internal types.

## File structure

```
iBruTests/
  DoseSchedulerTests.swift      — pure-logic scheduling tests
  MedicationPlanTests.swift     — computed property tests (doseSummary, isActive, etc.)
  QuickDoseRecordTests.swift    — QuickDoseRecord model + interval warning logic
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
            for: Baby.self, MedicationPlan.self, DoseRecord.self, IllnessRecord.self, QuickDoseRecord.self,
            configurations: config
        )
        context = ModelContext(container)
    }
}
```

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
- `DoseScheduler.scheduledTimes(for:on:calendar:)` — pure logic, easy to isolate
- Model computed properties: `isActive`, `isOngoing`, `frequencySummary`, `doseSummary`
- `FamilyService` error paths (mock the Firestore calls or test the `FamilyError` enum)

Avoid testing:
- Views (no UIKit/SwiftUI test infrastructure is set up)
- `FirestoreService` calls (require live Firebase; use integration tests for that)
- Anything that relies on `Date.now` without injecting the date

## Timezone safety

When testing time-based logic, pass an explicit UTC calendar to avoid timezone flakiness in CI:

```swift
private var utc: Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "UTC")!
    return c
}
```

## Running tests locally

```bash
xcodebuild test \
  -project iBru.xcodeproj \
  -scheme iBru \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  CODE_SIGNING_ALLOWED=NO
```

Or press ⌘U in Xcode.
