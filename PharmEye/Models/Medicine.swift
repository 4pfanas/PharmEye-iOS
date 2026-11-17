import Foundation

/// A single reminder time for a medicine (e.g. "8:00 AM, with breakfast").
struct ReminderTime: Identifiable, Codable, Hashable {
    var id = UUID()
    var time: Date
    var label: String   // "With breakfast", "Before bed", ...
    var enabled: Bool = true
}

/// Someone on the user's care team — doctor, pharmacist, carer.
struct CareContact: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var role: String     // "GP", "Pharmacist", ...
    var phone: String
}

enum DoseStatus: String, Codable, Equatable {
    case dueSoon, missed, onTrack, prn, finished
}

/// Core medicine record — persisted on-device (see PersistenceController).
/// Deliberately mirrors the prototype's data model 1:1: name, dose, schedule,
/// stock, and the two independent warning channels (allergyConflict vs.
/// cabinetInteractionNote) so the UI logic in MedicineDetailView doesn't have
/// to guess which banner to show.
struct Medicine: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var strength: String          // "625 mg"
    var composition: String       // "Amoxicillin 500 mg + clavulanic acid 125 mg"
    var barcode: String?
    var category: String          // "Antibiotic", "Reliever", ...
    var prescriptionOnly: Bool = false

    var isPRN: Bool = false                 // "as needed" — exempt from missed-dose tracking
    var reminderTimes: [ReminderTime] = []
    var repeatDays: Set<Int> = [1,2,3,4,5,6,7]   // 1 = Monday ... 7 = Sunday

    var courseDay: Int?           // e.g. 3 (of courseLength)
    var courseLength: Int?        // e.g. 7, nil = ongoing
    var dosesPerDay: Int
    var dosesLeft: Int
    /// How much one dose is ("1 tablet", "2 puffs"). Optional so older saved cabinets still decode.
    var doseAmount: String?

    var whatItTreats: String
    var howToTake: [String]
    var sideEffects: [String]

    var finishedOn: Date?         // set once a course completes

    /// Doses logged today, keyed by the ReminderTime id, so partial-day state survives relaunch.
    var loggedToday: Set<UUID> = []
}

/// Demo/seed data matching the values shown in the approved prototype, so early
/// screens look identical to what's already been signed off.
extension Medicine {
    static let sampleCabinet: [Medicine] = [
        Medicine(
            name: "Augmentin", strength: "625 mg",
            composition: "Amoxicillin 500 mg + clavulanic acid 125 mg · film-coated tablet",
            barcode: "6291234567890", category: "Antibiotic", prescriptionOnly: true,
            reminderTimes: [
                .init(time: .init(timeIntervalSinceNow: -3600*3), label: "After food"),
                .init(time: .init(timeIntervalSinceNow: 1500), label: "After food"),
                .init(time: .init(timeIntervalSinceNow: 3600*10), label: "After food")
            ],
            courseDay: 3, courseLength: 7, dosesPerDay: 3, dosesLeft: 11,
            whatItTreats: "A broad-spectrum antibiotic for bacterial infections of the chest, sinuses, ear, urinary tract, skin and teeth. It does nothing for colds or flu, which are viral.",
            howToTake: [
                "One tablet every 8 hours — 8:00 AM, 2:00 PM, 10:00 PM.",
                "Swallow whole at the start of a meal to reduce stomach upset.",
                "Finish the full 7 days even once you feel better.",
                "Missed a dose? Take it when you remember, unless the next is under 4 hours away."
            ],
            sideEffects: ["Diarrhoea, nausea or a mild stomach ache.", "Thrush after longer courses.", "Headache or dizziness in the first days."]
        ),
        Medicine(
            name: "Metformin", strength: "850 mg",
            composition: "Oral antidiabetic · film-coated tablet",
            barcode: "6290011447733", category: "Type 2 diabetes",
            reminderTimes: [
                .init(time: .init(timeIntervalSinceNow: -3600*8), label: "Morning"),
                .init(time: .init(timeIntervalSinceNow: -3600), label: "Evening")
            ],
            dosesPerDay: 2, dosesLeft: 40,
            whatItTreats: "Lowers blood sugar for type 2 diabetes.",
            howToTake: ["Take with meals to reduce stomach upset."],
            sideEffects: ["Stomach upset", "Metallic taste"]
        ),
        Medicine(
            name: "Ventolin", strength: "100 mcg",
            composition: "Salbutamol inhaler",
            barcode: "5013695003147", category: "Reliever", isPRN: true,
            dosesPerDay: 0, dosesLeft: 4,
            doseAmount: "2 puffs",
            whatItTreats: "Relieves asthma symptoms as needed.",
            howToTake: ["2 puffs as needed, max per pharmacist's guidance."],
            sideEffects: ["Mild tremor", "Fast heartbeat"]
        )
    ]
}
