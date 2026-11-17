import SwiftUI

/// 07 — Medicine Detail. Two independent, separately-labelled warning channels,
/// per the design spec: an allergy conflict (profile-based, red) and a cabinet-wide
/// interaction check (cross-medicine, amber) — with an explicit "no conflicts found"
/// line so a clean check is visible, not just silence.
struct MedicineDetailView: View {
    @EnvironmentObject private var cabinet: CabinetStore
    let medicine: Medicine

    private var allergyConflict: Bool { cabinet.allergyConflict(for: medicine) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                hero
                infoBlock(icon: "info.circle.fill", title: "What it treats", text: medicine.whatItTreats)
                bulletBlock(icon: "clock.fill", title: "How to take it", items: medicine.howToTake)
                bulletBlock(icon: "waveform.path.ecg", title: "Common side effects", items: medicine.sideEffects)

                if allergyConflict {
                    warningBanner(
                        icon: "exclamationmark.triangle.fill", tint: PETheme.rose,
                        title: "Allergy conflict on your profile",
                        text: "You listed a penicillin allergy. Amoxicillin is a penicillin. Do not take this without confirming with your doctor or pharmacist first."
                    )
                }

                interactionSection

                HStack(spacing: 10) {
                    NavigationLink("Edit schedule") { NotificationsView(initialTab: .reminders) }
                        .buttonStyle(PESecondaryButtonStyle())
                    if let med = cabinet.medicines.first(where: { $0.id == medicine.id }),
                       let reminder = cabinet.nextReminder(for: med) {
                        Button("Mark Taken") { cabinet.markTaken(med, reminder: reminder) }
                            .buttonStyle(PEPrimaryButtonStyle())
                    } else {
                        Button("Mark Taken") {}.buttonStyle(PEPrimaryButtonStyle())
                    }
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 22).padding(.bottom, 40)
        }
        .background(PEPaperBackground())
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            if medicine.prescriptionOnly { PEBadge(text: "Prescription only", tone: .orange) }
            Text("\(medicine.name) \(medicine.strength)").font(PETheme.display(25)).accessibilityAddTraits(.isHeader).foregroundStyle(PETheme.textPrimary)
            Text(medicine.composition).font(PETheme.body(13)).foregroundStyle(PETheme.textSecondary)

            HStack(spacing: 9) {
                statBox(medicine.courseDay.map { "\($0) / \(medicine.courseLength ?? 0)" } ?? "—", "DAY")
                statBox("\(medicine.dosesPerDay)×", "PER DAY")
                statBox("\(medicine.dosesLeft)", "LEFT")
            }
        }
        .padding(22)
        .peSurface(PETheme.card, radius: PETheme.radiusCardLg, seed: 41)
    }

    private func statBox(_ value: String, _ label: String) -> some View {
        VStack(spacing: 3) {
            Text(value).font(PETheme.bold(16)).foregroundStyle(PETheme.textPrimary)
            Text(label).font(PETheme.bold(10)).foregroundStyle(PETheme.textTertiary)
        }
        .frame(maxWidth: .infinity).padding(12)
        .peSurface(PETheme.card2, radius: 16, seed: label.count)
    }

    private func infoBlock(icon: String, title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Label(title, systemImage: icon).font(PETheme.bold(14)).foregroundStyle(PETheme.textPrimary)
                .labelStyle(.coloredIcon(spacing: 8, iconColor: PETheme.mar2))
            Text(text).font(PETheme.body(13.5)).foregroundStyle(PETheme.textSecondary).lineSpacing(3)
        }
    }

    private func bulletBlock(icon: String, title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Label(title, systemImage: icon).font(PETheme.bold(14)).foregroundStyle(PETheme.textPrimary)
                .labelStyle(.coloredIcon(spacing: 8, iconColor: PETheme.mar2))
            VStack(alignment: .leading, spacing: 8) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 9) {
                        Circle().fill(PETheme.mar2).frame(width: 5, height: 5).padding(.top, 7)
                        Text(item).font(PETheme.body(13.5)).foregroundStyle(PETheme.textSecondary).lineSpacing(2)
                    }
                }
            }
        }
    }

    private func warningBanner(icon: String, tint: Color, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: icon).foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(PETheme.bold(12.5)).foregroundStyle(tint)
                Text(text).font(PETheme.body(12.5)).foregroundStyle(PETheme.textPrimary).lineSpacing(2)
            }
        }
        .padding(15)
        .peSurface(tint.opacity(0.14), radius: 18, seed: title.count, stroke: tint.opacity(0.55))
    }

    @ViewBuilder private var interactionSection: some View {
        let warnings = cabinet.interactionWarnings(for: medicine)
        VStack(alignment: .leading, spacing: 10) {
            Label("Checked against your cabinet", systemImage: "shield.lefthalf.filled")
                .font(PETheme.bold(14)).foregroundStyle(PETheme.textPrimary)
                .labelStyle(.coloredIcon(spacing: 8, iconColor: PETheme.mar2))

            if warnings.isEmpty {
                Label("No conflicts found with your other \(max(cabinet.medicines.count - 1, 0)) medicines", systemImage: "checkmark.circle.fill")
                    .font(PETheme.body(11.5)).foregroundStyle(PETheme.textTertiary)
                    .labelStyle(.coloredIcon(spacing: 8, iconColor: PETheme.green))
            } else {
                ForEach(warnings, id: \.self) { note in
                    warningBanner(icon: "exclamationmark.triangle.fill", tint: PETheme.orange, title: "Interaction found", text: note)
                }
            }
        }
    }
}

/// A Label style that lets us pick the icon's tint independently of the text.
struct ColoredIconLabelStyle: LabelStyle {
    var spacing: CGFloat
    var iconColor: Color
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: spacing) {
            configuration.icon.foregroundStyle(iconColor)
            configuration.title
        }
    }
}
extension LabelStyle where Self == ColoredIconLabelStyle {
    static func coloredIcon(spacing: CGFloat, iconColor: Color) -> ColoredIconLabelStyle {
        ColoredIconLabelStyle(spacing: spacing, iconColor: iconColor)
    }
}
