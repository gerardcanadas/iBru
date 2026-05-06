Add a new frequency type to the medication scheduler.

## Files to change (in this order)

### 1. `iBru/Models/MedicationPlan.swift`

Add the new case to `FrequencyUnit` enum:
```swift
enum FrequencyUnit: String, Codable, CaseIterable {
    case everyNHours = "Every N hours"
    case timesPerDay = "Times per day"
    case specificDays = "Specific days"
    case everyNDays   = "Every N days"
    case myNewType    = "My new type"   // ADD HERE
}
```

Extend `frequencySummary` with a new `case`:
```swift
case .myNewType:
    return "..."
```

If the new type needs extra stored data (like `weekdays: [Int]` for specificDays), add a property with a default value. ALL SwiftData stored properties need explicit defaults.

### 2. `iBru/Utilities/DoseScheduler.swift`

Add a new case to the `switch plan.frequencyUnit` inside `scheduledTimes(for:on:)`.

The function signature:
```swift
static func scheduledTimes(for plan: MedicationPlan, on day: Date, calendar: Calendar = .current) -> [Date]
```

Key helpers already available:
- `distributedTimes(count:on:calendar:)` — distributes N doses evenly between 8am and 10pm
- `calendar.startOfDay(for:)` — strips time component
- `calendar.component(.weekday, from:)` — returns 1=Sun, 2=Mon, … 7=Sat

The function must return `[]` for days outside the plan's active window — the guard at the top already handles startDate/endDate, but your case must handle its own "this day doesn't apply" logic.

### 3. `iBru/Views/Plans/PlanFormView.swift`

The form has one `Stepper` driven by `stepperLabel` and `stepperRange` computed properties — update both switches to add your new case:

```swift
private var stepperLabel: String {
    switch frequencyUnit {
    // ... existing cases ...
    case .myNewType: return "..."
    }
}

private var stepperRange: ClosedRange<Int> {
    switch frequencyUnit {
    // ... existing cases ...
    case .myNewType: return 1...N
    }
}
```

Also update the `.onChange(of: frequencyUnit)` clamp logic.

If the new type needs extra UI (like the WeekdayPicker for specificDays), add it conditionally:
```swift
if frequencyUnit == .myNewType {
    MyCustomPicker(...)
}
```

Add any new `@State` vars for UI-only data, and update `isValid`, `applyMedicinePlan`, `loadFromPlan`, and `save` to round-trip them to/from the model.

## No other files need changing

`NotificationManager`, `TodayView`, `DashboardView`, `DoseRowView`, and `HistoryView` all go through `DoseScheduler.scheduledTimes` — they pick up new types automatically.

## Verification after implementing

Run `/build` to confirm no real compiler errors (SourceKit false positives are common here).
