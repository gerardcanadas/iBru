Wire up Firestore sync for a new SwiftData model.

Use this after `/new-model` to make a new model visible across all family devices.
The four steps below must all be completed for sync to work end-to-end.

## Architecture reminder

- `FirestoreService` (`iBru/Services/FirestoreService.swift`) is the single point of contact with Firestore
- Data lives under `families/{familyId}/{collection}/{docId}` — the familyId comes from `FamilyService.shared.familyId`
- Sync direction: on app launch, `syncAll` pulls Firestore → SwiftData; on every write, views push SwiftData → Firestore via `Task { await FirestoreService.shared.save(...) }`
- The model's `id: String` field is the Firestore document key

---

## Step 1 — Add `save` and `delete` to FirestoreService

In `iBru/Services/FirestoreService.swift`, add inside the `// MARK: - Save` section:

```swift
func save(_ item: MyModel) async {
    guard let ref = familyRef, let babyId = item.baby?.id else { return }
    var data: [String: Any] = [
        "id": item.id,
        "babyId": babyId,
        "title": item.title,
        "startDate": Timestamp(date: item.startDate),
        "notes": item.notes,
        "updatedAt": Timestamp()
    ]
    // add optional fields:
    if let end = item.endDate { data["endDate"] = Timestamp(date: end) }
    try? await ref.collection("myModels").document(item.id).setData(data)
}
```

And in `// MARK: - Delete`:

```swift
func delete(myModelId: String) async {
    guard let ref = familyRef else { return }
    try? await ref.collection("myModels").document(myModelId).delete()
}
```

For many-to-many relationships (like `IllnessRecord.plans`), store the related IDs as an array:
```swift
data["relatedIds"] = item.relatedItems.map(\.id)
```

---

## Step 2 — Add write-through to all views that write this model

In every view that inserts, updates, or deletes a `MyModel` record, add the corresponding Firestore call:

**After `modelContext.insert(r)` or after mutating an existing record:**
```swift
Task { await FirestoreService.shared.save(r) }
```

**Before/after `modelContext.delete(r)` — capture id first:**
```swift
let id = r.id
modelContext.delete(r)
Task { await FirestoreService.shared.delete(myModelId: id) }
```

**Inline button mutations (DetailView actions):**
```swift
r.someField = newValue
Task { await FirestoreService.shared.save(r) }
```

---

## Step 3 — Add the model to `syncAll` in FirestoreService

Inside `syncAll(context:)`, after the existing sections for babies/plans/records/illnesses, add:

```swift
// Fetch
let myModelsSnap = try? await ref.collection("myModels").getDocuments()

// Build local map
var myModelsByID: [String: MyModel] = [:]
for m in (try? context.fetch(FetchDescriptor<MyModel>())) ?? [] { myModelsByID[m.id] = m }
var seenMyModels = Set<String>()

// Upsert from Firestore
for doc in myModelsSnap?.documents ?? [] {
    let d = doc.data()
    guard let id = d["id"] as? String,
          let babyId = d["babyId"] as? String,
          let title = d["title"] as? String,
          let startDate = (d["startDate"] as? Timestamp)?.dateValue() else { continue }
    seenMyModels.insert(id)
    let notes = d["notes"] as? String ?? ""
    let endDate = (d["endDate"] as? Timestamp)?.dateValue()
    if let existing = myModelsByID[id] {
        existing.title = title; existing.startDate = startDate
        existing.endDate = endDate; existing.notes = notes
    } else {
        let item = MyModel(title: title, startDate: startDate, endDate: endDate, notes: notes)
        item.id = id
        item.baby = babiesByID[babyId]
        context.insert(item)
        myModelsByID[id] = item
    }
}

// Delete local records absent from Firestore
for (id, m) in myModelsByID where !seenMyModels.contains(id) { context.delete(m) }
```

Add the new variable to `ensureStableIDs` too:
```swift
for m in (try? context.fetch(FetchDescriptor<MyModel>())) ?? [] where m.id.isEmpty {
    m.id = UUID().uuidString; changed = true
}
```

And add it to `pushAll`:
```swift
let myModels = (try? context.fetch(FetchDescriptor<MyModel>())) ?? []
for m in myModels { await save(m) }
```

---

## Step 4 — Verify

1. Create a new record on Device/Simulator A → kill and reopen on Device/Simulator B → record should appear after relaunch
2. Delete a record on A → reopen on B → record should be gone
3. Check the Firebase Console → Firestore → `families/{id}/myModels` to confirm documents are being written

Run `/build` after all changes to confirm no compiler errors.
