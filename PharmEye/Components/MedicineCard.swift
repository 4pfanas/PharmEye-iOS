import SwiftUI

/// Full card, used in Cabinet's default (card) view. Mirrors .med-card in the prototype:
/// a coloured left stripe for status, title + badge, code/day line, and a schedule row.
struct MedicineCard: View {
    let medicine: Medicine
    let status: DoseStatus

    private var stripeColor: Color {
        switch status {
        case .missed: PETheme.roseFill
        case .dueSoon: PETheme.orangeFill
        case .onTrack: PETheme.greenFill
        case .prn: PETheme.orangeFill
        case .finished: PETheme.textTertiary
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 0, bottomTrailingRadius: 3, topTrailingRadius: 3, style: .continuous)
                .fill(stripeColor)
                .frame(width: 3)
                .padding(.vertical, 18)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    Text(titleLine)
                        .font(PETheme.bold(15.5))
                        .foregroundStyle(PETheme.textPrimary)
                        .lineLimit(2)
                    Spacer()
                    badge
                }
                Text(codeLine)
                    .font(PETheme.body(11.5))
                    .foregroundStyle(PETheme.textTertiary)

                HStack {
                    Label(medicine.category + (takenWithFood ? " · after food" : ""), systemImage: "pills")
                        .font(PETheme.semibold(11.5))
                        .foregroundStyle(PETheme.textSecondary)
                        .lineLimit(1)
                    Spacer()
                    scheduleChips
                }
            }
            .padding(16)
        }
        .peSurface(PETheme.card, radius: PETheme.radiusCard, seed: medicine.name.count * 7)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the medicine details")
    }

    private var takenWithFood: Bool {
        !medicine.isPRN && medicine.howToTake.joined(separator: " ").localizedCaseInsensitiveContains("meal")
            || medicine.reminderTimes.contains { $0.label.localizedCaseInsensitiveContains("food") }
    }

    private var titleLine: String {
        if let len = medicine.courseLength {
            "\(medicine.name) \(medicine.strength) — \(len)-day course"
        } else {
            "\(medicine.name) \(medicine.strength)"
        }
    }

    private var codeLine: String {
        let code = medicine.barcode.map { "EAN \($0)" } ?? "No barcode on file"
        if let day = medicine.courseDay, let len = medicine.courseLength {
            return "\(code) · day \(day) of \(len)"
        }
        return medicine.isPRN ? "\(code) · reliever" : "\(code) · ongoing"
    }

    @ViewBuilder private var badge: some View {
        switch status {
        case .missed: PEBadge(text: "Missed", tone: .rose)
        case .dueSoon: PEBadge(text: "Due soon", tone: .orange)
        case .onTrack: PEBadge(text: "Active", tone: .green)
        case .prn: PEBadge(text: "\(medicine.dosesLeft) left", tone: .orange)
        case .finished: PEBadge(text: "Course done", tone: .mute)
        }
    }

    private var scheduleChips: some View {
        HStack(spacing: 4) {
            ForEach(medicine.reminderTimes.prefix(4)) { r in
                Text(r.time, format: .dateTime.hour().minute())
                    .font(PETheme.bold(10))
                    .lineLimit(1).fixedSize()
                    .foregroundStyle(PETheme.textSecondary)
                    .padding(.horizontal, 7).padding(.vertical, 4)
                    .background(PETheme.card3, in: RoundedRectangle(cornerRadius: 7))
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(PETheme.line))
            }
        }
    }
}

/// Compact row, used in Cabinet's "compact view" (fixes density past ~15 medicines) —
/// grouped under Due today / Ongoing / As needed / Finished section headers.
struct MedicineCompactRow: View {
    let medicine: Medicine
    let status: DoseStatus
    let timeLabel: String

    private var dotColor: Color {
        switch status {
        case .missed: PETheme.roseFill
        case .dueSoon: PETheme.orangeFill
        case .onTrack: PETheme.greenFill
        case .prn: PETheme.mar2
        case .finished: PETheme.textTertiary
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Circle().fill(dotColor).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(medicine.name) \(medicine.strength)")
                    .font(PETheme.semibold(13.5)).foregroundStyle(PETheme.textPrimary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(PETheme.body(11)).foregroundStyle(PETheme.textTertiary)
                    .lineLimit(1)
            }
            Spacer()
            Text(timeLabel)
                .font(PETheme.bold(11)).foregroundStyle(PETheme.textTertiary)
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .peSurface(PETheme.card, radius: 16, seed: medicine.name.count * 5)
        .accessibilityElement(children: .combine)
        .opacity(status == .finished ? 0.55 : 1)
    }

    private var subtitle: String {
        if status == .missed { return "Missed — tap to log late" }
        if let day = medicine.courseDay, let len = medicine.courseLength { return "Day \(day) of \(len) · after food" }
        if medicine.isPRN { return "\(medicine.category) · \(medicine.dosesLeft) doses left" }
        return medicine.category
    }
}
