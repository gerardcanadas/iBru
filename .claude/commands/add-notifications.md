Wire up push notification scheduling for a new plan-like model.

## How notifications work in this project

- `NotificationManager` is a singleton at `iBru/Utilities/NotificationManager.swift`
- Notifications are scheduled via `UNCalendarNotificationTrigger` using times from `DoseScheduler.scheduledTimes(for:on:)`
- The app pre-schedules **7 days** of notifications on every plan save/edit
- Each notification carries a payload: `["planID": plan.persistentModelID, "slot": time.timeIntervalSince1970]`
- `AppDelegate` handles notification actions (MARK_TAKEN, SKIP_DOSE) and creates `DoseRecord` entries

## To add notifications for a new feature

### Step 1 — Call scheduleNotifications after save

In the new feature's `FormView.save()`, add after `modelContext.insert(p)`:
```swift
NotificationManager.shared.scheduleNotifications(for: p)
```

Also add it to the edit branch (same pattern as `PlanFormView`).

### Step 2 — Cancel notifications on delete

In the List view's delete handler, add before `modelContext.delete(record)`:
```swift
NotificationManager.shared.cancelAllNotifications(for: record)
```

Check `NotificationManager` for existing `cancelAllNotifications` overloads. If a new overload is needed, follow the existing pattern:
```swift
func cancelAllNotifications(for plan: MedicationPlan) {
    let prefix = "ibru-\(plan.persistentModelID)"
    UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
        let ids = requests.filter { $0.identifier.hasPrefix(prefix) }.map(\.identifier)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }
}
```

### Step 3 — Cancel when baby is deleted

In `BabyListView` or wherever baby deletion happens, cancel notifications for all of the baby's plans:
```swift
for plan in baby.plans {
    NotificationManager.shared.cancelAllNotifications(for: plan)
}
modelContext.delete(baby)
```

### Step 4 — Handle notification actions in AppDelegate (if needed)

If the new feature needs interactive notification actions (like "Mark Taken"):
1. Define a new action identifier in `NotificationManager.requestPermission()`
2. Add a new category with the action
3. Handle the action in `AppDelegate.userNotificationCenter(_:didReceive:)` by parsing the userInfo payload and creating the appropriate record

## Do not change

- `DoseScheduler` — notification timing comes from it automatically
- `UNUserNotificationCenter` setup in `requestPermission()` — only add new categories, don't replace existing ones
