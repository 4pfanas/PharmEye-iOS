import SwiftUI

/// 11 — Notifications and reminders in one place. "Alerts" is built live from the
/// cabinet (due now, missed, running low, taken); "Reminders" is every scheduled time
/// per medicine, each switchable, plus the master "Dose reminders" switch.
struct NotificationsView: View {
    enum Tab: String, CaseIterable { case alerts = "Alerts", reminders = "Reminders" }

    @EnvironmentObject private var cabinet: CabinetStore
    @Environment(\.dismiss) private var dismiss
    @State private var tab: Tab
    @State private var showScanner = false
    @State private var snoozed: Set<UUID> = []
    @AppStorage(ReminderScheduler.enabledKey) private var remindersOn = true

    init(initialTab: Tab = .alerts) {
        _tab = State(initialValue: initialTab)
    }

    var body: some View {
        ZStack {
            PEPaperBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Button { dismiss() } label: { PEHeaderIconButton(systemImage: "chevron.left") }
                        Spacer()
                        Button { showScanner = true } label: { PEHeaderIconButton(systemImage: "barcode.viewfinder", square: true) }
                    }
                    Text("Notifications").font(PETheme.display(29)).accessibilityAddTraits(.isHeader).foregroundStyle(PETheme.textPrimary)
                    tabSwitch

                    switch tab {
                    case .alerts: alertsTab
                    case .reminders: remindersTab
                    }
                }
                .padding(.horizontal, 22).padding(.top, 4).padding(.bottom, 30)
            }
        }
        .toolbar(.hidden)
        .sheet(isPresented: $showScanner) {
            ScannerView { cabinet.addScannedMedicine($0) }
        }
    }

    private var tabSwitch: some View {
        HStack(spacing: 6) {
            ForEach(Tab.allCases, id: \.self) { t in
                Text(t.rawValue)
                    .font(PETheme.semibold(13.5))
                    .foregroundStyle(tab == t ? PETheme.onMar : PETheme.textSecondary)
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                    .peSurface(tab == t ? PETheme.mar : PETheme.card2, radius: PETheme.radiusPill, seed: t.rawValue.count,
                               stroke: tab == t ? PETheme.textPrimary : PETheme.line2)
                    .peChipTraits(selected: tab == t)
                    .onTapGesture { withAnimation(.snappy) { tab = t } }
            }
        }
    }

    // MARK: Alerts

    private struct Alert: Identifiable {
        enum Kind { case due, missed, low, taken }
        let id: String
        let kind: Kind
        let medicine: Medicine
        var reminder: ReminderTime?
    }

    private var alerts: [Alert] {
        var out: [Alert] = []
        let now = Date()
        for med in cabinet.medicines where med.finishedOn == nil {
            if !med.isPRN {
                for r in med.reminderTimes where r.enabled && !med.loggedToday.contains(r.id) {
                    switch MissedDoseEngine.status(for: r, isPRN: false, loggedAt: nil, now: now) {
                    case .dueSoon: out.append(.init(id: "due\(r.id)", kind: .due, medicine: med, reminder: r))
                    case .missed: out.append(.init(id: "missed\(r.id)", kind: .missed, medicine: med, reminder: r))
                    default: break
                    }
                }
                if !med.loggedToday.isEmpty {
                    out.append(.init(id: "taken\(med.id)", kind: .taken, medicine: med))
                }
            }
            if med.dosesLeft <= 5 {
                out.append(.init(id: "low\(med.id)", kind: .low, medicine: med))
            }
        }
        let order: [Alert.Kind: Int] = [.due: 0, .missed: 1, .low: 2, .taken: 3]
        return out.sorted { order[$0.kind]! < order[$1.kind]! }
    }

    @ViewBuilder private var alertsTab: some View {
        let all = alerts
        let attention = all.filter { $0.kind != .taken }
        let done = all.filter { $0.kind == .taken }

        if all.isEmpty {
            emptyState(icon: "checkmark.seal.fill", title: "You're all caught up",
                       text: "Nothing is due, missed or running low right now.")
        }
        if !attention.isEmpty {
            group("Needs attention") { ForEach(attention) { alertCard($0) } }
        }
        if !done.isEmpty {
            group("Done today") { ForEach(done) { alertCard($0) } }
        }
    }

    @ViewBuilder private func alertCard(_ a: Alert) -> some View {
        let med = a.medicine
        let title = "\(med.name) \(med.strength)".trimmingCharacters(in: .whitespaces)
        let time = a.reminder.map { $0.time.formatted(date: .omitted, time: .shortened) } ?? ""
        switch a.kind {
        case .due:
            card(icon: "pill.fill", tint: PETheme.mar2, tintBg: PETheme.mar.opacity(0.2),
                 title: "Time for \(title)", unread: true,
                 text: "\(a.reminder?.label ?? "Scheduled dose"). Take it within the next hour to stay on time.",
                 time: snoozed.contains(med.id) ? "\(time) · snoozed 15 min" : "\(time) · \(Self.relative(a.reminder?.time))") {
                actionButton("Mark Taken", primary: true) {
                    if let r = a.reminder { withAnimation { cabinet.markTaken(med, reminder: r) } }
                }
                actionButton("Snooze 15 min") {
                    ReminderScheduler.snooze(med)
                    snoozed.insert(med.id)
                }
            }
        case .missed:
            card(icon: "xmark", tint: PETheme.rose, tintBg: PETheme.roseDim,
                 title: "Missed \(title)",
                 text: "The \(time) dose wasn't marked. If you took it, log it late. Never double the next dose.",
                 time: time) {
                actionButton("Log it late", primary: true) {
                    if let r = a.reminder { withAnimation { cabinet.markTaken(med, reminder: r) } }
                }
            }
        case .low:
            card(icon: "exclamationmark.triangle.fill", tint: PETheme.orange, tintBg: PETheme.orangeDim,
                 title: "\(med.name) running low",
                 text: "About \(med.dosesLeft) \(med.dosesLeft == 1 ? "dose" : "doses") left. Plan a refill soon.",
                 time: "Stock") { EmptyView() }
        case .taken:
            card(icon: "checkmark", tint: PETheme.green, tintBg: PETheme.greenDim,
                 title: "\(med.name) logged",
                 text: "\(med.loggedToday.count) of \(med.reminderTimes.count) doses taken today.",
                 time: "Today") { EmptyView() }
        }
    }

    // MARK: Reminders

    @ViewBuilder private var remindersTab: some View {
        HStack(spacing: 12) {
            Image(systemName: "bell.fill").foregroundStyle(PETheme.mar2)
                .frame(width: 40, height: 40).background(PETheme.mar.opacity(0.2), in: RoundedRectangle(cornerRadius: 13))
            VStack(alignment: .leading, spacing: 2) {
                Text("Dose reminders").font(PETheme.semibold(14)).foregroundStyle(PETheme.textPrimary)
                Text(remindersOn ? "On · \(cabinet.activeReminderCount) scheduled on this phone" : "Off · no alerts will fire")
                    .font(PETheme.body(12)).foregroundStyle(PETheme.textTertiary)
            }
            Spacer()
            Toggle("", isOn: $remindersOn).labelsHidden().tint(PETheme.mar)
        }
        .padding(15)
        .peSurface(PETheme.card, radius: 20)
        .onChange(of: remindersOn) { _, on in
            if on {
                Task {
                    _ = await ReminderScheduler.requestAuthorization()
                    ReminderScheduler.scheduleAll(cabinet.medicines)
                }
            } else {
                ReminderScheduler.cancelAll()
            }
        }

        let scheduled = cabinet.medicines.filter { !$0.isPRN && $0.finishedOn == nil }
        let asNeeded = cabinet.medicines.filter(\.isPRN)

        if cabinet.medicines.isEmpty {
            emptyState(icon: "clock.fill", title: "No reminders yet",
                       text: "Add a medicine from the Cabinet and its reminder times show up here.")
        }

        ForEach(scheduled) { med in
            group("\(med.name) \(med.strength)") {
                VStack(spacing: 0) {
                    ForEach(med.reminderTimes.sorted { $0.time < $1.time }) { r in
                        reminderRow(med, r)
                    }
                }
                .peSurface(PETheme.card, radius: 20, seed: med.name.count)
                .opacity(remindersOn ? 1 : 0.5)
            }
        }

        if !asNeeded.isEmpty {
            group("As needed") {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(asNeeded) { med in
                        Text("\(med.name) \(med.strength) · \(med.dosesLeft) doses left")
                            .font(PETheme.semibold(13.5)).foregroundStyle(PETheme.textPrimary)
                    }
                    Text("No reminders. These are never marked missed.")
                        .font(PETheme.body(12)).foregroundStyle(PETheme.textTertiary)
                }
                .padding(15)
                .frame(maxWidth: .infinity, alignment: .leading)
                .peSurface(PETheme.card, radius: 20, seed: 3)
            }
        }
    }

    private func reminderRow(_ med: Medicine, _ r: ReminderTime) -> some View {
        let taken = med.loggedToday.contains(r.id)
        let status = MissedDoseEngine.status(for: r, isPRN: false, loggedAt: taken ? .now : nil)
        let (label, tone): (String, PEBadge.Tone) = taken ? ("Taken", .green)
            : status == .missed ? ("Missed", .rose)
            : status == .dueSoon ? ("Due now", .gold)
            : ("Upcoming", .mute)
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(r.time, format: .dateTime.hour().minute())
                    .font(PETheme.bold(18)).foregroundStyle(PETheme.textPrimary)
                Text(r.label).font(PETheme.semibold(11.5)).foregroundStyle(PETheme.textTertiary)
            }
            Spacer()
            if r.enabled { PEBadge(text: label, tone: tone) }
            Toggle("", isOn: Binding(
                get: { r.enabled },
                set: { cabinet.setReminder(r.id, of: med, enabled: $0) }
            ))
            .labelsHidden().tint(PETheme.mar)
        }
        .padding(.horizontal, 15).padding(.vertical, 12)
        .overlay(alignment: .bottom) { Rectangle().fill(PETheme.line).frame(height: 1).padding(.horizontal, 15) }
    }

    // MARK: Building blocks

    /// "now" once the dose time has arrived, otherwise "in N min".
    static func relative(_ date: Date?) -> String {
        guard let date else { return "now" }
        let mins = Int(date.timeIntervalSinceNow / 60)
        return mins > 0 ? "in \(mins) min" : "now"
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title.uppercased()).font(PETheme.bold(11)).foregroundStyle(PETheme.textTertiary)
            content()
        }
    }

    private func emptyState(icon: String, title: String, text: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 26)).foregroundStyle(PETheme.mar2)
            Text(title).font(PETheme.bold(17)).foregroundStyle(PETheme.textPrimary)
            Text(text).font(PETheme.prose(14)).foregroundStyle(PETheme.textSecondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 40)
    }

    private func actionButton(_ title: String, primary: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(PETheme.bold(12.5)).foregroundStyle(primary ? PETheme.onMar : PETheme.textPrimary)
                .padding(.horizontal, 14).padding(.vertical, 9)
                .peSurface(primary ? PETheme.mar : PETheme.card2, radius: 11, seed: title.count,
                           stroke: primary ? PETheme.textPrimary : PETheme.line2)
        }
        .buttonStyle(.plain)
    }

    private func card<Actions: View>(icon: String, tint: Color, tintBg: Color, title: String, unread: Bool = false,
                                     text: String, time: String, @ViewBuilder actions: () -> Actions) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).foregroundStyle(tint)
                .frame(width: 40, height: 40).background(tintBg, in: RoundedRectangle(cornerRadius: 13))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(PETheme.bold(14)).foregroundStyle(PETheme.textPrimary)
                Text(text).font(PETheme.body(12.5)).foregroundStyle(PETheme.textSecondary).lineSpacing(2)
                Text(time).font(PETheme.semibold(11)).foregroundStyle(PETheme.textTertiary)
                HStack(spacing: 8) { actions() }.padding(.top, 3)
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .peSurface(unread ? PETheme.mar.opacity(0.09) : PETheme.card, radius: 20, seed: title.count,
                   stroke: unread ? PETheme.mar : PETheme.line2)
    }
}
