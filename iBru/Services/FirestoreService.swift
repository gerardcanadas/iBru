import FirebaseFirestore
import SwiftData

final class FirestoreService {
    static let shared = FirestoreService()
    private let db = Firestore.firestore()
    private init() {}

    private var familyRef: DocumentReference? {
        guard let fid = FamilyService.shared.familyId else { return nil }
        return db.collection("families").document(fid)
    }

    // MARK: - Save

    func save(_ baby: Baby) async {
        guard let ref = familyRef else { return }
        try? await ref.collection("babies").document(baby.id).setData([
            "id": baby.id,
            "name": baby.name,
            "birthDate": Timestamp(date: baby.birthDate),
            "colorHex": baby.colorHex,
            "updatedAt": Timestamp()
        ])
    }

    func save(_ plan: MedicationPlan) async {
        guard let ref = familyRef, let babyId = plan.baby?.id else { return }
        var data: [String: Any] = [
            "id": plan.id,
            "babyId": babyId,
            "medicationName": plan.medicationName,
            "doseAmount": plan.doseAmount,
            "doseUnit": plan.doseUnit,
            "frequencyUnit": plan.frequencyUnit.rawValue,
            "frequencyValue": plan.frequencyValue,
            "weekdays": plan.weekdays,
            "startDate": Timestamp(date: plan.startDate),
            "notes": plan.notes,
            "updatedAt": Timestamp()
        ]
        if let end = plan.endDate { data["endDate"] = Timestamp(date: end) }
        if let stopped = plan.stoppedDate { data["stoppedDate"] = Timestamp(date: stopped) }
        try? await ref.collection("plans").document(plan.id).setData(data)
    }

    func save(_ record: DoseRecord) async {
        guard let ref = familyRef, let planId = record.plan?.id else { return }
        try? await ref.collection("records").document(record.id).setData([
            "id": record.id,
            "planId": planId,
            "scheduledDate": Timestamp(date: record.scheduledDate),
            "recordedDate": Timestamp(date: record.recordedDate),
            "status": record.status.rawValue,
            "updatedAt": Timestamp()
        ])
    }

    func save(_ quick: QuickDoseRecord) async {
        guard let ref = familyRef, let babyId = quick.baby?.id else { return }
        let data: [String: Any] = [
            "id": quick.id,
            "babyId": babyId,
            "medicationName": quick.medicationName,
            "doseAmount": quick.doseAmount,
            "doseUnit": quick.doseUnit,
            "givenAt": Timestamp(date: quick.givenAt),
            "notes": quick.notes,
            "updatedAt": Timestamp()
        ]
        try? await ref.collection("quickDoses").document(quick.id).setData(data)
    }

    func save(_ illness: IllnessRecord) async {
        guard let ref = familyRef, let babyId = illness.baby?.id else { return }
        var data: [String: Any] = [
            "id": illness.id,
            "babyId": babyId,
            "title": illness.title,
            "startDate": Timestamp(date: illness.startDate),
            "notes": illness.notes,
            "planIds": illness.plans.map(\.id),
            "updatedAt": Timestamp()
        ]
        if let end = illness.endDate { data["endDate"] = Timestamp(date: end) }
        try? await ref.collection("illnesses").document(illness.id).setData(data)
    }

    // MARK: - Delete

    func delete(babyId: String) async {
        guard let ref = familyRef else { return }
        try? await ref.collection("babies").document(babyId).delete()
    }

    func delete(planId: String) async {
        guard let ref = familyRef else { return }
        try? await ref.collection("plans").document(planId).delete()
    }

    func delete(recordId: String) async {
        guard let ref = familyRef else { return }
        try? await ref.collection("records").document(recordId).delete()
    }

    func delete(illnessId: String) async {
        guard let ref = familyRef else { return }
        try? await ref.collection("illnesses").document(illnessId).delete()
    }

    func delete(quickDoseId: String) async {
        guard let ref = familyRef else { return }
        try? await ref.collection("quickDoses").document(quickDoseId).delete()
    }

    // MARK: - Sync

    @MainActor
    func syncAll(context: ModelContext) async {
        ensureStableIDs(context: context)
        guard let ref = familyRef else { return }

        let babiesSnap = try? await ref.collection("babies").getDocuments()
        let plansSnap = try? await ref.collection("plans").getDocuments()
        let recordsSnap = try? await ref.collection("records").getDocuments()
        let illnessesSnap = try? await ref.collection("illnesses").getDocuments()
        let quickDosesSnap = try? await ref.collection("quickDoses").getDocuments()

        // If fetch failed (e.g. permission denied), bail without touching local data
        guard let babyDocs = babiesSnap?.documents else { return }
        // First setup: Firestore is empty, push local data up
        guard !babyDocs.isEmpty else {
            await pushAll(context: context)
            return
        }

        var babiesByID: [String: Baby] = [:]
        var plansByID: [String: MedicationPlan] = [:]
        var recordsByID: [String: DoseRecord] = [:]
        var illnessesByID: [String: IllnessRecord] = [:]
        var quickDosesByID: [String: QuickDoseRecord] = [:]

        for b in (try? context.fetch(FetchDescriptor<Baby>())) ?? [] { babiesByID[b.id] = b }
        for p in (try? context.fetch(FetchDescriptor<MedicationPlan>())) ?? [] { plansByID[p.id] = p }
        for r in (try? context.fetch(FetchDescriptor<DoseRecord>())) ?? [] { recordsByID[r.id] = r }
        for i in (try? context.fetch(FetchDescriptor<IllnessRecord>())) ?? [] { illnessesByID[i.id] = i }
        for q in (try? context.fetch(FetchDescriptor<QuickDoseRecord>())) ?? [] { quickDosesByID[q.id] = q }

        var seenBabies = Set<String>()
        var seenPlans = Set<String>()
        var seenRecords = Set<String>()
        var seenIllnesses = Set<String>()
        var seenQuickDoses = Set<String>()

        for doc in babyDocs {
            let d = doc.data()
            guard let id = d["id"] as? String,
                  let name = d["name"] as? String,
                  let birthDate = (d["birthDate"] as? Timestamp)?.dateValue(),
                  let colorHex = d["colorHex"] as? String else { continue }
            seenBabies.insert(id)
            if let baby = babiesByID[id] {
                baby.name = name; baby.birthDate = birthDate; baby.colorHex = colorHex
            } else {
                let baby = Baby(name: name, birthDate: birthDate, colorHex: colorHex)
                baby.id = id
                context.insert(baby)
                babiesByID[id] = baby
            }
        }

        for doc in plansSnap?.documents ?? [] {
            let d = doc.data()
            guard let id = d["id"] as? String,
                  let babyId = d["babyId"] as? String,
                  let name = d["medicationName"] as? String,
                  let amount = d["doseAmount"] as? Double,
                  let unit = d["doseUnit"] as? String,
                  let freqRaw = d["frequencyUnit"] as? String,
                  let freq = FrequencyUnit(rawValue: freqRaw),
                  let freqVal = d["frequencyValue"] as? Int,
                  let startDate = (d["startDate"] as? Timestamp)?.dateValue() else { continue }
            seenPlans.insert(id)
            let notes = d["notes"] as? String ?? ""
            let weekdays = d["weekdays"] as? [Int] ?? []
            let endDate = (d["endDate"] as? Timestamp)?.dateValue()
            let stoppedDate = (d["stoppedDate"] as? Timestamp)?.dateValue()
            if let plan = plansByID[id] {
                plan.medicationName = name; plan.doseAmount = amount; plan.doseUnit = unit
                plan.frequencyUnit = freq; plan.frequencyValue = freqVal
                plan.weekdays = weekdays; plan.startDate = startDate
                plan.endDate = endDate; plan.notes = notes; plan.stoppedDate = stoppedDate
            } else {
                let plan = MedicationPlan(medicationName: name, doseAmount: amount, doseUnit: unit,
                                          frequencyUnit: freq, frequencyValue: freqVal,
                                          startDate: startDate, endDate: endDate, notes: notes)
                plan.id = id
                plan.weekdays = weekdays
                plan.stoppedDate = stoppedDate
                plan.baby = babiesByID[babyId]
                context.insert(plan)
                plansByID[id] = plan
            }
        }

        for doc in recordsSnap?.documents ?? [] {
            let d = doc.data()
            guard let id = d["id"] as? String,
                  let planId = d["planId"] as? String,
                  let scheduled = (d["scheduledDate"] as? Timestamp)?.dateValue(),
                  let recorded = (d["recordedDate"] as? Timestamp)?.dateValue(),
                  let statusRaw = d["status"] as? String,
                  let status = DoseStatus(rawValue: statusRaw) else { continue }
            seenRecords.insert(id)
            if let record = recordsByID[id] {
                record.scheduledDate = scheduled; record.recordedDate = recorded; record.status = status
            } else {
                let record = DoseRecord(scheduledDate: scheduled, recordedDate: recorded, status: status)
                record.id = id
                record.plan = plansByID[planId]
                context.insert(record)
                recordsByID[id] = record
            }
        }

        for doc in illnessesSnap?.documents ?? [] {
            let d = doc.data()
            guard let id = d["id"] as? String,
                  let babyId = d["babyId"] as? String,
                  let title = d["title"] as? String,
                  let startDate = (d["startDate"] as? Timestamp)?.dateValue() else { continue }
            seenIllnesses.insert(id)
            let notes = d["notes"] as? String ?? ""
            let endDate = (d["endDate"] as? Timestamp)?.dateValue()
            let planIds = d["planIds"] as? [String] ?? []
            let linkedPlans = planIds.compactMap { plansByID[$0] }
            if let illness = illnessesByID[id] {
                illness.title = title; illness.startDate = startDate
                illness.endDate = endDate; illness.notes = notes; illness.plans = linkedPlans
            } else {
                let illness = IllnessRecord(title: title, startDate: startDate, endDate: endDate, notes: notes)
                illness.id = id
                illness.baby = babiesByID[babyId]
                illness.plans = linkedPlans
                context.insert(illness)
                illnessesByID[id] = illness
            }
        }

        for doc in quickDosesSnap?.documents ?? [] {
            let d = doc.data()
            guard let id = d["id"] as? String,
                  let babyId = d["babyId"] as? String,
                  let name = d["medicationName"] as? String,
                  let amount = d["doseAmount"] as? Double,
                  let unit = d["doseUnit"] as? String,
                  let givenAt = (d["givenAt"] as? Timestamp)?.dateValue() else { continue }
            seenQuickDoses.insert(id)
            let notes = d["notes"] as? String ?? ""
            if let existing = quickDosesByID[id] {
                existing.medicationName = name; existing.doseAmount = amount
                existing.doseUnit = unit; existing.givenAt = givenAt; existing.notes = notes
            } else {
                let q = QuickDoseRecord(medicationName: name, doseAmount: amount, doseUnit: unit, givenAt: givenAt, notes: notes)
                q.id = id
                q.baby = babiesByID[babyId]
                context.insert(q)
                quickDosesByID[id] = q
            }
        }

        for (id, b) in babiesByID where !seenBabies.contains(id) { context.delete(b) }
        for (id, p) in plansByID where !seenPlans.contains(id) { context.delete(p) }
        for (id, r) in recordsByID where !seenRecords.contains(id) { context.delete(r) }
        for (id, i) in illnessesByID where !seenIllnesses.contains(id) { context.delete(i) }
        for (id, q) in quickDosesByID where !seenQuickDoses.contains(id) { context.delete(q) }
    }

    // MARK: - Ensure migrated records have stable IDs

    @MainActor
    private func ensureStableIDs(context: ModelContext) {
        var changed = false
        for b in (try? context.fetch(FetchDescriptor<Baby>())) ?? [] where b.id.isEmpty {
            b.id = UUID().uuidString; changed = true
        }
        for p in (try? context.fetch(FetchDescriptor<MedicationPlan>())) ?? [] where p.id.isEmpty {
            p.id = UUID().uuidString; changed = true
        }
        for r in (try? context.fetch(FetchDescriptor<DoseRecord>())) ?? [] where r.id.isEmpty {
            r.id = UUID().uuidString; changed = true
        }
        for i in (try? context.fetch(FetchDescriptor<IllnessRecord>())) ?? [] where i.id.isEmpty {
            i.id = UUID().uuidString; changed = true
        }
        for q in (try? context.fetch(FetchDescriptor<QuickDoseRecord>())) ?? [] where q.id.isEmpty {
            q.id = UUID().uuidString; changed = true
        }
        if changed { try? context.save() }
    }

    // MARK: - Push local data to Firestore (first-time setup)

    @MainActor
    private func pushAll(context: ModelContext) async {
        let babies = (try? context.fetch(FetchDescriptor<Baby>())) ?? []
        let plans = (try? context.fetch(FetchDescriptor<MedicationPlan>())) ?? []
        let records = (try? context.fetch(FetchDescriptor<DoseRecord>())) ?? []
        let illnesses = (try? context.fetch(FetchDescriptor<IllnessRecord>())) ?? []
        let quickDoses = (try? context.fetch(FetchDescriptor<QuickDoseRecord>())) ?? []
        for b in babies { await save(b) }
        for p in plans { await save(p) }
        for r in records { await save(r) }
        for i in illnesses { await save(i) }
        for q in quickDoses { await save(q) }
    }
}
