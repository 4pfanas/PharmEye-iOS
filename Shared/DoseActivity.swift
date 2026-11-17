import ActivityKit
import AppIntents
import Foundation

/// Shared by the app and the PharmEyeWidget extension: what the Dynamic Island /
/// Lock Screen Live Activity shows for the next dose.
nonisolated struct DoseActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var medicineID: UUID
        var medicineName: String
        var strength: String
        var doseAmount: String
        var label: String          // "After food", "Before bed", ...
        var dueAt: Date
        var dosesLeftToday: Int
        var taken: Bool            // flips to true for a moment after Mark Taken
    }
}

/// The Mark Taken button inside the Live Activity. LiveActivityIntents run in the
/// app's process, so the real work happens in the app target; the widget build
/// only needs the type to draw the button.
struct MarkDoseTakenIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Mark dose taken"
    static let isDiscoverable = false

    @Parameter(title: "Medicine ID") var medicineID: String

    init() {}
    init(medicineID: UUID) { self.medicineID = medicineID.uuidString }

    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        await MainActor.run {
            let store = CabinetStore.shared
            if let id = UUID(uuidString: medicineID),
               let med = store.medicines.first(where: { $0.id == id }) {
                store.logDose(med)
            }
            DoseLiveActivity.refresh(justTaken: true)
        }
        #endif
        return .result()
    }
}
