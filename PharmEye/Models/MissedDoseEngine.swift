import Foundation

/// Implements the missed-dose rule agreed in the design pass (see canvas annotation
/// "row-missed-dose-logic" and /areas/pharmeye.md):
///
/// - Each scheduled time is independent — a grace window of -30/+60 min around the
///   scheduled time counts as "on time." Nothing before or after that window is
///   auto-shifted onto the next dose.
/// - After the grace window closes unlogged, the dose flips to `.missed`.
/// - Logging it later the same day records it as "taken late" — distinct from
///   on-time, but it still counts toward stock and adherence.
/// - A missed dose never doubles the next one — nothing here ever suggests
///   "take two now."
/// - PRN (as-needed) medicines are exempt entirely: they only ever report `.prn`.
enum MissedDoseEngine {

    static let graceBefore: TimeInterval = 30 * 60
    static let graceAfter: TimeInterval = 60 * 60

    /// Status for one specific reminder time "today," given whether it's logged.
    static func status(for reminder: ReminderTime, isPRN: Bool, loggedAt: Date?, now: Date = .init()) -> DoseStatus {
        if isPRN { return .prn }
        if loggedAt != nil { return .onTrack } // "taken" (on-time or late — caller can label the difference)

        let scheduled = reminder.time
        let windowStart = scheduled.addingTimeInterval(-graceBefore)
        let windowEnd = scheduled.addingTimeInterval(graceAfter)

        if now < windowStart {
            return .onTrack // upcoming, not due yet — shown as "in N min" by the caller
        } else if now <= windowEnd {
            return .dueSoon // inside the grace window right now
        } else {
            return .missed // grace window closed, never logged
        }
    }

    /// True if a dose logged at `loggedAt` should be labelled "taken late" rather
    /// than "on time," per the -30/+60 grace window.
    static func wasLate(reminder: ReminderTime, loggedAt: Date) -> Bool {
        let windowEnd = reminder.time.addingTimeInterval(graceAfter)
        return loggedAt > windowEnd
    }

    /// A day counts toward the adherence streak only if every scheduled non-PRN
    /// dose that day was logged (on-time or late). One missed dose breaks it.
    static func dayIsOnStreak(medicines: [Medicine], loggedIDs: Set<UUID>, day: Date, calendar: Calendar = .current) -> Bool {
        for med in medicines where !med.isPRN {
            for reminder in med.reminderTimes where calendar.isDate(reminder.time, inSameDayAs: day) {
                if !loggedIDs.contains(reminder.id) { return false }
            }
        }
        return true
    }
}
