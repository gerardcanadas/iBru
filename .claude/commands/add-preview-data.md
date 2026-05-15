Add sample data for a new model to the preview container.

## Where preview data lives

`iBru/Utilities/PreviewContainer.swift` — creates an in-memory `ModelContainer` used by all `#Preview` blocks.

## Current test data

- Baby "Pau" (male, birthDate 90 days ago, colorHex "#5B8DEF")
- MedicationPlan "Paracetamol" — 5ml, every 8h, started ~10h ago; one DoseRecord (taken) at first slot today
- MedicationPlan "Vitamin D" — 0.5ml, 1x/day, 7-day span starting 3 days ago
- QuickDoseRecord "Paracetamol" — 5ml, 3h ago
- IllnessRecord "Cold" — resolved 20–18 days ago; "Bronchitis" — ongoing from 10 days ago (with 2 TemperatureReadings); "Fever" — resolved 60–55 days ago
- VaccineRecord "MMR" — pending; "DTaP-1" — given 30 days ago
- GrowthRecord × 3 — at 60, 30, and 0 days ago (weight + height + head circumference)
- DailyNote × 3 — today, yesterday, and 3 days ago

## How to add data for a new model

1. Insert after the existing `modelContext.insert(plan1)` / `modelContext.insert(plan2)` lines
2. Set the `.baby` (or parent) reference so relationships resolve correctly
3. Add at least one "active/ongoing" instance and one "past/ended" instance so List views show both sections in previews
4. Keep dates relative to `Date.now` so previews don't go stale

Example:
```swift
let illness = IllnessRecord(title: "Cold", startDate: .now.addingTimeInterval(-5 * 86400))
illness.baby = baby
illness.plans = [plan1]
modelContext.insert(illness)

let pastIllness = IllnessRecord(
    title: "Ear infection",
    startDate: .now.addingTimeInterval(-30 * 86400),
    endDate: .now.addingTimeInterval(-20 * 86400)
)
pastIllness.baby = baby
modelContext.insert(pastIllness)
```

## After adding preview data

Run a `#Preview` in Xcode to visually confirm the new data appears correctly in both list sections.

If the new model was added to the schema in `iBruApp.swift`, ensure `PreviewContainer.swift` also includes it in its `ModelContainer(for:)` call. The full current list is:
`Baby.self, MedicationPlan.self, DoseRecord.self, IllnessRecord.self, QuickDoseRecord.self, TemperatureReading.self, VaccineRecord.self, GrowthRecord.self, DailyNote.self`
