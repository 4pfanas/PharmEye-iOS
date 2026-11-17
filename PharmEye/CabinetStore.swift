import Foundation
import Combine

/// Single source of truth for the medicine cabinet, injected as an EnvironmentObject.
/// Persists to a JSON file in the app's Documents folder; views only ever talk to
/// this store, never to the file.
@MainActor
final class CabinetStore: ObservableObject {
    /// The one store the app, Siri/Shortcuts intents and the Live Activity button share.
    static let shared = CabinetStore()

    @Published var medicines: [Medicine]
    @Published var hasScannedFirstMedicine: Bool
    @Published var hasSetAllergyProfile: Bool

    private let saveURL: URL

    init(preview: Bool = false) {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.saveURL = dir.appendingPathComponent("cabinet.json")

        if preview {
            self.medicines = Medicine.sampleCabinet
            self.hasScannedFirstMedicine = true
            self.hasSetAllergyProfile = false
            return
        }

        // Load medicines first
        let loadedMedicines: [Medicine]
        if let data = try? Data(contentsOf: saveURL),
           let decoded = try? JSONDecoder().decode([Medicine].self, from: data) {
            loadedMedicines = decoded
        } else {
            #if DEBUG
            // Debug builds start with the demo cabinet once, then persist like the real app.
            loadedMedicines = FileManager.default.fileExists(atPath: saveURL.path) ? [] : Medicine.sampleCabinet
            #else
            loadedMedicines = []
            #endif
        }

        // Initialize all stored properties before using self
        self.medicines = loadedMedicines
        self.hasSetAllergyProfile = UserDefaults.standard.bool(forKey: "hasSetAllergyProfile")
        self.hasScannedFirstMedicine = !loadedMedicines.isEmpty
        rollOverToToday()
        save()
    }

    /// Reminder times are stored as full dates, and `loggedToday` is per-day. On the
    /// first open of a new day, clear yesterday's logs and move every reminder onto
    /// today (same hour and minute) so the missed-dose rules run against today.
    func rollOverToToday(now: Date = .init()) {
        let key = "cabinet.day"
        let today = Calendar.current.startOfDay(for: now)
        let last = UserDefaults.standard.object(forKey: key) as? Date
        guard last.map({ !Calendar.current.isDate($0, inSameDayAs: today) }) ?? true else { return }

        for m in medicines.indices {
            medicines[m].loggedToday = []
            for r in medicines[m].reminderTimes.indices {
                let hm = Calendar.current.dateComponents([.hour, .minute], from: medicines[m].reminderTimes[r].time)
                medicines[m].reminderTimes[r].time = Calendar.current.date(
                    bySettingHour: hm.hour ?? 0, minute: hm.minute ?? 0, second: 0, of: today) ?? medicines[m].reminderTimes[r].time
            }
        }
        UserDefaults.standard.set(today, forKey: key)
        save()
    }

    func save() {
        if let data = try? JSONEncoder().encode(medicines) {
            try? data.write(to: saveURL)
        }
        // Every change to doses flows through here, so the Dynamic Island countdown stays in step.
        DoseLiveActivity.refresh(store: self)
    }

    func status(for medicine: Medicine, now: Date = .init()) -> DoseStatus {
        if medicine.finishedOn != nil { return .finished }
        if medicine.isPRN { return .prn }
        guard let next = nextReminder(for: medicine, now: now) else { return .onTrack }
        let loggedAt = medicine.loggedToday.contains(next.id) ? now : nil
        return MissedDoseEngine.status(for: next, isPRN: false, loggedAt: loggedAt, now: now)
    }

    /// The next (or currently-due) reminder time for a medicine today.
    func nextReminder(for medicine: Medicine, now: Date = .init()) -> ReminderTime? {
        medicine.reminderTimes
            .filter { !medicine.loggedToday.contains($0.id) }
            .min { $0.time < $1.time }
        ?? medicine.reminderTimes.first
    }

    func markTaken(_ medicine: Medicine, reminder: ReminderTime) {
        guard let idx = medicines.firstIndex(where: { $0.id == medicine.id }) else { return }
        medicines[idx].loggedToday.insert(reminder.id)
        if medicines[idx].dosesLeft > 0 { medicines[idx].dosesLeft -= 1 }
        save()
    }

    func addScannedMedicine(_ medicine: Medicine) {
        medicines.append(medicine)
        hasScannedFirstMedicine = true
        save()
        ReminderScheduler.schedule(medicine)
    }

    /// As-needed doses have no reminder to tick off — they only draw down stock.
    func logPRNDose(_ medicine: Medicine) {
        guard let idx = medicines.firstIndex(where: { $0.id == medicine.id }),
              medicines[idx].dosesLeft > 0 else { return }
        medicines[idx].dosesLeft -= 1
        save()
    }

    /// The dose to act on next: the one due now or coming up, falling back to the
    /// earliest missed one (so it can still be logged late). nil once today is done.
    func pendingReminder(for medicine: Medicine) -> ReminderTime? {
        guard !medicine.isPRN, !allTakenToday(medicine) else { return nil }
        let open = medicine.reminderTimes
            .filter { $0.enabled && !medicine.loggedToday.contains($0.id) }
            .sorted { $0.time < $1.time }
        let missed: (ReminderTime) -> Bool = {
            MissedDoseEngine.status(for: $0, isPRN: false, loggedAt: nil) == .missed
        }
        return open.first { !missed($0) } ?? open.first
    }

    /// The soonest upcoming (not missed) dose across the whole cabinet.
    func nextDose(now: Date = .init()) -> (medicine: Medicine, reminder: ReminderTime)? {
        medicines.filter { $0.finishedOn == nil }
            .compactMap { med in pendingReminder(for: med).map { (med, $0) } }
            .filter { MissedDoseEngine.status(for: $0.1, isPRN: false, loggedAt: nil, now: now) != .missed }
            .min { $0.1.time < $1.1.time }
    }

    /// "Log a dose" for any medicine: ticks off the pending reminder, or draws down
    /// stock for an as-needed one. Returns false when there was nothing to log.
    @discardableResult
    func logDose(_ medicine: Medicine) -> Bool {
        if medicine.isPRN {
            guard medicine.dosesLeft > 0 else { return false }
            logPRNDose(medicine)
            return true
        }
        guard let r = pendingReminder(for: medicine) else { return false }
        markTaken(medicine, reminder: r)
        return true
    }

    /// True once every reminder for this medicine has been logged today.
    func allTakenToday(_ medicine: Medicine) -> Bool {
        !medicine.isPRN && !medicine.reminderTimes.isEmpty
            && medicine.reminderTimes.allSatisfy { medicine.loggedToday.contains($0.id) }
    }

    /// Scheduled (non-PRN) doses still to take today, across the whole cabinet.
    var dosesLeftToday: Int {
        medicines.filter { !$0.isPRN && $0.finishedOn == nil }
            .reduce(0) { total, med in
                total + med.reminderTimes.filter { $0.enabled && !med.loggedToday.contains($0.id) }.count
            }
    }

    /// (taken, scheduled) for today, used by the Profile stats row.
    var takenToday: (taken: Int, scheduled: Int) {
        let active = medicines.filter { !$0.isPRN && $0.finishedOn == nil }
        let scheduled = active.reduce(0) { $0 + $1.reminderTimes.filter(\.enabled).count }
        let taken = active.reduce(0) { $0 + $1.loggedToday.count }
        return (taken, scheduled)
    }

    var activeReminderCount: Int {
        medicines.filter { $0.finishedOn == nil }.reduce(0) { $0 + $1.reminderTimes.filter(\.enabled).count }
    }

    func setReminder(_ reminderID: UUID, of medicine: Medicine, enabled: Bool) {
        guard let m = medicines.firstIndex(where: { $0.id == medicine.id }),
              let r = medicines[m].reminderTimes.firstIndex(where: { $0.id == reminderID }) else { return }
        medicines[m].reminderTimes[r].enabled = enabled
        save()
        ReminderScheduler.schedule(medicines[m])
    }

    // MARK: Health profile — allergies, conditions, care team (on-device only)

    @Published var allergies: Set<String> = Set(UserDefaults.standard.stringArray(forKey: "profile.allergies") ?? []) {
        didSet { UserDefaults.standard.set(Array(allergies), forKey: "profile.allergies") }
    }
    @Published var conditions: String = UserDefaults.standard.string(forKey: "profile.conditions") ?? "" {
        didSet { UserDefaults.standard.set(conditions, forKey: "profile.conditions") }
    }
    @Published var careTeam: [CareContact] = CabinetStore.loadCareTeam() {
        didSet {
            if let data = try? JSONEncoder().encode(careTeam) {
                UserDefaults.standard.set(data, forKey: "profile.careTeam")
            }
        }
    }

    private static func loadCareTeam() -> [CareContact] {
        guard let data = UserDefaults.standard.data(forKey: "profile.careTeam") else { return [] }
        return (try? JSONDecoder().decode([CareContact].self, from: data)) ?? []
    }

    func saveHealthProfile(allergies: Set<String>, conditions: String) {
        self.allergies = allergies
        self.conditions = conditions
        hasSetAllergyProfile = true
        UserDefaults.standard.set(true, forKey: "hasSetAllergyProfile")
    }

    /// Flags penicillin-class antibiotics when the profile lists a penicillin allergy.
    func allergyConflict(for medicine: Medicine) -> Bool {
        guard allergies.contains("Penicillin") else { return false }
        let text = (medicine.name + " " + medicine.composition).lowercased()
        return ["penicillin", "amoxicillin", "ampicillin", "augmentin"].contains { text.contains($0) }
    }

    /// Everything the user could export: cabinet + health profile, as pretty JSON.
    func exportData() -> Data {
        struct Export: Encodable {
            let exportedAt: Date
            let medicines: [Medicine]
            let allergies: [String]
            let conditions: String
            let careTeam: [CareContact]
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let export = Export(exportedAt: .now, medicines: medicines, allergies: allergies.sorted(),
                            conditions: conditions, careTeam: careTeam)
        return (try? encoder.encode(export)) ?? Data()
    }

    /// "Delete my data": cabinet file, profile, care team, stored AI key and every
    /// pending reminder. Irreversible — the UI confirms first.
    func deleteAllData() {
        medicines = []
        allergies = []
        conditions = ""
        careTeam = []
        hasScannedFirstMedicine = false
        hasSetAllergyProfile = false
        try? FileManager.default.removeItem(at: saveURL)
        for key in ["hasSetAllergyProfile", "profile.allergies", "profile.conditions", "profile.careTeam",
                    "profile.name", "profile.age", "profile.gender", "ai.provider"] {
            UserDefaults.standard.removeObject(forKey: key)
        }
        Keychain.delete(account: Keychain.aiKeyAccount)
        ReminderScheduler.cancelAll()
        AuthStore.shared.signOut()
    }

    /// Checks a newly-scanned/added medicine against everything already in the
    /// cabinet. This is deliberately separate from the profile-allergy check —
    /// two independent warning channels, per the design spec.
    func interactionWarnings(for medicine: Medicine) -> [String] {
        // Built-in rule set. Warnings are informational and always point the user to
        // their pharmacist; they are never presented as medical advice.
        var notes: [String] = []
        if medicine.name.localizedCaseInsensitiveContains("Augmentin"),
           medicines.contains(where: { $0.name.localizedCaseInsensitiveContains("Metformin") }) {
            notes.append("Moderate interaction with Metformin 850 mg — amoxicillin can occasionally affect blood sugar control. Watch for unusual readings while you're on both, and mention it to your pharmacist.")
        }
        return notes
    }
}
