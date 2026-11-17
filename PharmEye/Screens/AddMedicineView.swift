import SwiftUI

/// 12 — Add a medicine by hand. Function spec #4 "fully pre-scheduled at creation
/// time": Save adds the medicine to the cabinet and schedules every enabled reminder
/// locally right away, so they fire offline / with the app closed.
struct AddMedicineView: View {
    @EnvironmentObject private var cabinet: CabinetStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var strength = ""
    @State private var dose = "1 tablet"
    @State private var frequency = "Twice"
    @State private var times: [ReminderTime] = AddMedicineView.defaultTimes(for: "Twice")
    @State private var repeatDays: Set<Int> = [1,2,3,4,5,6,7]
    @State private var showScanner = false
    private let frequencies = ["Once", "Twice", "3× daily", "As needed"]
    private let dayLabels = ["M","T","W","T","F","S","S"]
    private let dayNames = ["Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday"]

    private var isPRN: Bool { frequency == "As needed" }
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        ZStack {
            PEPaperBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Button { dismiss() } label: { PEHeaderIconButton(systemImage: "xmark") }
                        Spacer()
                        Button { showScanner = true } label: { PEHeaderIconButton(systemImage: "barcode.viewfinder", square: true) }
                    }
                    Text("Add a medicine").font(PETheme.display(29)).accessibilityAddTraits(.isHeader).foregroundStyle(PETheme.textPrimary)
                    Text("Scan the box to fill this in automatically, or type it yourself.")
                        .font(PETheme.prose(14.5)).foregroundStyle(PETheme.textSecondary)

                    field("Medicine") { TextField("e.g. Panadol", text: $name).textFieldStyle(PEFieldStyle()) }
                    HStack(spacing: 10) {
                        field("Strength") { TextField("e.g. 500 mg", text: $strength).textFieldStyle(PEFieldStyle()) }
                        field("Each dose") { TextField("1 tablet", text: $dose).textFieldStyle(PEFieldStyle()) }
                    }
                    field("How often") {
                        HStack(spacing: 8) {
                            ForEach(frequencies, id: \.self) { f in
                                Text(f)
                                    .font(PETheme.semibold(13.5))
                                    .foregroundStyle(frequency == f ? PETheme.onMar : PETheme.textSecondary)
                                    .lineLimit(1).fixedSize()
                                    .padding(.horizontal, 13).padding(.vertical, 11)
                                    .peSurface(frequency == f ? PETheme.mar : PETheme.card, radius: PETheme.radiusPill, seed: f.count,
                                               stroke: frequency == f ? PETheme.textPrimary : PETheme.line2)
                                    .peChipTraits(selected: frequency == f)
                                    .onTapGesture {
                                        frequency = f
                                        withAnimation(.snappy) { times = Self.defaultTimes(for: f) }
                                    }
                            }
                        }
                    }

                    if isPRN {
                        note("As-needed medicines don't get reminders and are never marked as missed. You log a dose whenever you take one.")
                    } else {
                        remindersSection
                    }

                    Button("Save medicine") { save() }
                        .buttonStyle(PEPrimaryButtonStyle()).padding(.top, 4)
                        .disabled(!canSave)
                    Button("Cancel") { dismiss() }.buttonStyle(PESecondaryButtonStyle())
                }
                .padding(.horizontal, 22).padding(.top, 4).padding(.bottom, 40)
            }
        }
        .toolbar(.hidden)
        .sheet(isPresented: $showScanner) {
            ScannerView { medicine in
                cabinet.addScannedMedicine(medicine)
                dismiss()
            }
        }
    }

    @ViewBuilder private var remindersSection: some View {
        Text("REMINDER TIMES").font(PETheme.bold(11)).foregroundStyle(PETheme.textTertiary).padding(.top, 6)
        VStack(spacing: 9) {
            ForEach($times) { $t in
                HStack(spacing: 12) {
                    Circle().fill(PETheme.mar.opacity(0.18)).frame(width: 38, height: 38)
                        .overlay(Image(systemName: "clock.fill").font(.system(size: 15)).foregroundStyle(PETheme.mar2))
                    VStack(alignment: .leading, spacing: 2) {
                        DatePicker("", selection: $t.time, displayedComponents: .hourAndMinute)
                            .labelsHidden().tint(PETheme.mar)
                        Text(t.label).font(PETheme.semibold(11.5)).foregroundStyle(PETheme.textTertiary)
                    }
                    Spacer()
                    Toggle("", isOn: $t.enabled).labelsHidden().tint(PETheme.mar)
                }
                .padding(14)
                .peSurface(PETheme.card, radius: 18, seed: t.label.count)
            }
            Button {
                times.append(.init(time: .now, label: "Extra dose"))
            } label: {
                HStack { Image(systemName: "plus"); Text("Add another time") }
            }
            .font(PETheme.semibold(13.5)).foregroundStyle(PETheme.textSecondary)
            .frame(maxWidth: .infinity).frame(height: 48)
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5])).foregroundStyle(PETheme.line2))
        }

        Text("REPEAT ON").font(PETheme.bold(11)).foregroundStyle(PETheme.textTertiary).padding(.top, 6)
        HStack(spacing: 7) {
            ForEach(Array(dayLabels.enumerated()), id: \.offset) { idx, d in
                let dayNum = idx + 1
                Text(d)
                    .font(PETheme.bold(12))
                    .foregroundStyle(repeatDays.contains(dayNum) ? PETheme.onMar : PETheme.textTertiary)
                    .frame(maxWidth: .infinity).frame(height: 44)
                    .peSurface(repeatDays.contains(dayNum) ? PETheme.mar : PETheme.card, radius: 13, seed: idx,
                               stroke: repeatDays.contains(dayNum) ? PETheme.textPrimary : PETheme.line2)
                    .accessibilityLabel(dayNames[idx])
                    .peChipTraits(selected: repeatDays.contains(dayNum))
                    .onTapGesture {
                        if repeatDays.contains(dayNum) { repeatDays.remove(dayNum) } else { repeatDays.insert(dayNum) }
                    }
            }
        }

        note("Reminders are scheduled on your phone the moment you save, so they fire on time even offline or with the app closed.")
            .padding(.top, 6)
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        // A time that's already passed today starts tomorrow, so a medicine added at
        // night isn't instantly "missed" for its morning dose.
        let enabled: [ReminderTime] = isPRN ? [] : times.map { t in
            var t = t
            if t.time < .now { t.time = Calendar.current.date(byAdding: .day, value: 1, to: t.time) ?? t.time }
            return t
        }
        let medicine = Medicine(
            name: trimmedName,
            strength: strength.trimmingCharacters(in: .whitespaces),
            composition: "Added by hand",
            category: isPRN ? "As needed" : "Added by hand",
            isPRN: isPRN,
            reminderTimes: enabled,
            repeatDays: repeatDays,
            dosesPerDay: enabled.filter(\.enabled).count,
            dosesLeft: 30,
            doseAmount: dose.isEmpty ? nil : dose,
            whatItTreats: "Added by hand, so PharmEye doesn't have the leaflet details yet. Scan the box to fill this in.",
            howToTake: ["\(dose.isEmpty ? "1 dose" : dose), \(frequency.lowercased())."],
            sideEffects: []
        )
        Task {
            if !isPRN { _ = await ReminderScheduler.requestAuthorization() }
            cabinet.addScannedMedicine(medicine)
            dismiss()
        }
    }

    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(PETheme.bold(12)).foregroundStyle(PETheme.textSecondary)
            content()
        }
    }

    private func note(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill").foregroundStyle(PETheme.textTertiary).padding(.top, 1)
            Text(text).font(PETheme.body(11.5)).foregroundStyle(PETheme.textSecondary).lineSpacing(2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .peSurface(PETheme.card, radius: 16)
    }

    static func defaultTimes(for frequency: String) -> [ReminderTime] {
        func at(_ h: Int, _ label: String) -> ReminderTime {
            .init(time: Calendar.current.date(bySettingHour: h, minute: 0, second: 0, of: .now) ?? .now, label: label)
        }
        switch frequency {
        case "Once": return [at(9, "Morning")]
        case "Twice": return [at(8, "With breakfast"), at(20, "With dinner")]
        case "3× daily": return [at(8, "With breakfast"), at(14, "With lunch"), at(22, "Before bed")]
        default: return []
        }
    }
}
