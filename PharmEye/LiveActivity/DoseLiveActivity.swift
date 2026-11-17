import ActivityKit
import Foundation

/// Keeps one Live Activity — the Dynamic Island / Lock Screen dose countdown — in step
/// with the cabinet. Call `refresh()` whenever doses change or the app comes forward.
///
/// iOS only lets an app *start* a Live Activity while it is in the foreground (or via a
/// push server, which PharmEye doesn't have), so the countdown begins the next time the
/// app is opened with a dose due within the next 8 hours, then updates from Mark Taken.
enum DoseLiveActivity {
    /// How far ahead a dose has to be before it gets a countdown.
    static let lookahead: TimeInterval = 8 * 60 * 60

    @MainActor
    static func refresh(store: CabinetStore? = nil, justTaken: Bool = false) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let store = store ?? .shared
        let current = Activity<DoseActivityAttributes>.activities

        guard let next = store.nextDose(), next.reminder.time.timeIntervalSinceNow < lookahead else {
            // Nothing coming up: end any countdown, briefly showing "All done" if a dose was just taken.
            Task {
                for activity in current {
                    var state = activity.content.state
                    state.taken = justTaken
                    state.dosesLeftToday = store.dosesLeftToday
                    await activity.end(.init(state: state, staleDate: nil),
                                       dismissalPolicy: justTaken ? .after(.now + 5) : .immediate)
                }
            }
            return
        }

        let state = DoseActivityAttributes.ContentState(
            medicineID: next.medicine.id,
            medicineName: next.medicine.name,
            strength: next.medicine.strength,
            doseAmount: next.medicine.doseAmount ?? "1 tablet",
            label: next.reminder.label,
            dueAt: next.reminder.time,
            dosesLeftToday: store.dosesLeftToday,
            taken: false)
        let content = ActivityContent(state: state, staleDate: next.reminder.time.addingTimeInterval(MissedDoseEngine.graceAfter))

        if let activity = current.first {
            Task { await activity.update(content) }
            // Only one countdown at a time.
            for extra in current.dropFirst() { Task { await extra.end(nil, dismissalPolicy: .immediate) } }
        } else {
            _ = try? Activity.request(attributes: DoseActivityAttributes(), content: content, pushType: nil)
        }
    }
}
