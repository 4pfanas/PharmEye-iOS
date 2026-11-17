import AppIntents
import Foundation

/// Siri & Shortcuts. Each intent runs inside the app process against
/// `CabinetStore.shared`, so a dose logged by voice shows up on Home immediately.

struct MedicineEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Medicine"
    static let defaultQuery = MedicineQuery()

    let id: UUID
    let name: String
    let strength: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(strength)")
    }

    init(_ medicine: Medicine) {
        id = medicine.id
        name = medicine.name
        strength = medicine.strength
    }
}

struct MedicineQuery: EntityStringQuery {
    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [MedicineEntity] {
        CabinetStore.shared.medicines.filter { identifiers.contains($0.id) }.map(MedicineEntity.init)
    }

    @MainActor
    func entities(matching string: String) async throws -> [MedicineEntity] {
        CabinetStore.shared.medicines
            .filter { $0.name.localizedCaseInsensitiveContains(string) }
            .map(MedicineEntity.init)
    }

    @MainActor
    func suggestedEntities() async throws -> [MedicineEntity] {
        CabinetStore.shared.medicines.filter { $0.finishedOn == nil }.map(MedicineEntity.init)
    }
}

struct LogDoseIntent: AppIntent {
    static let title: LocalizedStringResource = "Log a dose"
    static let description = IntentDescription("Marks your next dose of a medicine as taken.")

    @Parameter(title: "Medicine") var medicine: MedicineEntity

    init() {}
    init(medicine: MedicineEntity) { self.medicine = medicine }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = CabinetStore.shared
        guard let med = store.medicines.first(where: { $0.id == medicine.id }) else {
            return .result(dialog: "I couldn't find \(medicine.name) in your cabinet.")
        }
        guard store.logDose(med) else {
            return .result(dialog: med.isPRN
                ? "\(med.name) has no doses left. Time for a refill."
                : "You've already taken every \(med.name) dose for today.")
        }
        DoseLiveActivity.refresh()
        let left = store.dosesLeftToday
        return .result(dialog: "Logged \(med.name) \(med.strength). \(left == 0 ? "That's everything for today." : "\(left) \(left == 1 ? "dose" : "doses") left today.")")
    }
}

struct NextDoseIntent: AppIntent {
    static let title: LocalizedStringResource = "Next dose"
    static let description = IntentDescription("Tells you which medicine is due next and when.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let next = CabinetStore.shared.nextDose() else {
            return .result(dialog: "Nothing else is scheduled for today.")
        }
        let time = next.reminder.time.formatted(date: .omitted, time: .shortened)
        let amount = next.medicine.doseAmount ?? "1 tablet"
        return .result(dialog: "Next is \(next.medicine.name) \(next.medicine.strength), \(amount), at \(time).")
    }
}

struct CheckTakenIntent: AppIntent {
    static let title: LocalizedStringResource = "Did I take my medicine?"
    static let description = IntentDescription("Checks how many doses of a medicine you've taken today.")

    @Parameter(title: "Medicine") var medicine: MedicineEntity

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let med = CabinetStore.shared.medicines.first(where: { $0.id == medicine.id }) else {
            return .result(dialog: "I couldn't find \(medicine.name) in your cabinet.")
        }
        if med.isPRN {
            return .result(dialog: "\(med.name) is as-needed, so there's no schedule to miss. \(med.dosesLeft) doses left.")
        }
        let taken = med.loggedToday.count, total = med.reminderTimes.filter(\.enabled).count
        if taken == 0 { return .result(dialog: "Not yet. You haven't logged any \(med.name) today.") }
        if taken >= total { return .result(dialog: "Yes, all \(total) \(med.name) doses are logged today.") }
        return .result(dialog: "You've taken \(taken) of \(total) \(med.name) doses today.")
    }
}

struct PharmEyeShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: LogDoseIntent(), phrases: [
            "Log my \(\.$medicine) in \(.applicationName)",
            "I took my \(\.$medicine) in \(.applicationName)",
            "Log a dose in \(.applicationName)"
        ], shortTitle: "Log a dose", systemImageName: "checkmark.circle")
        AppShortcut(intent: NextDoseIntent(), phrases: [
            "What's my next dose in \(.applicationName)",
            "When is my next medicine in \(.applicationName)"
        ], shortTitle: "Next dose", systemImageName: "clock")
        AppShortcut(intent: CheckTakenIntent(), phrases: [
            "Did I take my \(\.$medicine) in \(.applicationName)",
            "Have I taken my \(\.$medicine) with \(.applicationName)"
        ], shortTitle: "Did I take it?", systemImageName: "questionmark.circle")
    }
}
