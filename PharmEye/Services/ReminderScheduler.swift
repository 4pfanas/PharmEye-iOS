import Foundation
import UserNotifications

/// Local dose reminders. Every enabled reminder time is scheduled on-device the moment
/// a medicine is saved (function spec #4: "fully pre-scheduled at creation time"), so
/// alerts fire offline and with the app closed. Nothing goes through a server.
nonisolated enum ReminderScheduler {

    /// Master switch, shown as "Dose reminders" in Notifications → Reminders.
    static let enabledKey = "reminders.enabled"
    static var isEnabled: Bool { UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true }

    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// Replaces every pending request for this medicine with its current schedule.
    static func schedule(_ medicine: Medicine) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { pending in
            let center = UNUserNotificationCenter.current()
            let mine = pending.map(\.identifier).filter { $0.hasPrefix(medicine.id.uuidString) }
            center.removePendingNotificationRequests(withIdentifiers: mine)

            guard isEnabled, !medicine.isPRN, medicine.finishedOn == nil else { return }
            for reminder in medicine.reminderTimes where reminder.enabled {
                for (suffix, trigger) in triggers(for: reminder, days: medicine.repeatDays) {
                    let request = UNNotificationRequest(
                        identifier: "\(medicine.id.uuidString).\(reminder.id.uuidString).\(suffix)",
                        content: content(for: medicine, label: reminder.label),
                        trigger: trigger)
                    center.add(request)
                }
            }
        }
    }

    static func scheduleAll(_ medicines: [Medicine]) {
        medicines.forEach(schedule)
    }

    /// One-off nudge `minutes` from now, for "Snooze 15 min".
    static func snooze(_ medicine: Medicine, minutes: Int = 15) {
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(minutes * 60), repeats: false)
        let request = UNNotificationRequest(identifier: "\(medicine.id.uuidString).snooze",
                                            content: content(for: medicine, label: "Snoozed reminder"),
                                            trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    static func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    private static func content(for medicine: Medicine, label: String) -> UNMutableNotificationContent {
        let c = UNMutableNotificationContent()
        c.title = "Time for \(medicine.name) \(medicine.strength)"
        c.body = "\(label). Open PharmEye to mark it taken."
        c.sound = .default
        return c
    }

    /// Every day selected → one daily trigger (keeps well under iOS's 64-pending cap).
    /// Otherwise one weekly trigger per selected day.
    private static func triggers(for reminder: ReminderTime, days: Set<Int>) -> [(String, UNCalendarNotificationTrigger)] {
        let hm = Calendar.current.dateComponents([.hour, .minute], from: reminder.time)
        if days.count == 7 || days.isEmpty {
            return [("daily", UNCalendarNotificationTrigger(dateMatching: hm, repeats: true))]
        }
        return days.sorted().map { day in
            var c = hm
            c.weekday = day % 7 + 1   // model: 1 = Monday … 7 = Sunday; Calendar: 1 = Sunday
            return ("d\(day)", UNCalendarNotificationTrigger(dateMatching: c, repeats: true))
        }
    }
}
