import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var cabinet: CabinetStore
    @AppStorage("profile.name") private var profileName = ""
    @State private var showScanner = false
    @State private var scannedMedicine: Medicine?
    /// The medicine shown in the big card. nil = whichever dose is coming up next.
    @State private var selectedID: UUID?

    var body: some View {
        ZStack {
            PEPaperBackground()

            if cabinet.medicines.isEmpty {
                HomeFirstRunView(showScanner: $showScanner)
            } else {
                homeContent
            }
        }
        .toolbar(.hidden)
        .sheet(isPresented: $showScanner) {
            ScannerView { medicine in handleScan(medicine) }
        }
        // Onboarding-trust payoff: the very first scan surfaces the allergy/conditions
        // ask contextually, using the real conflict it just found as the reason.
        .sheet(item: $scannedMedicine) { medicine in
            HealthProfilePromptView(medicineName: medicine.name) { allergies, conditions in
                cabinet.saveHealthProfile(allergies: allergies, conditions: conditions)
            } onDismiss: {}
        }
    }

    private func handleScan(_ medicine: Medicine) {
        let isFirstScan = !cabinet.hasScannedFirstMedicine
        cabinet.addScannedMedicine(medicine)
        if isFirstScan && !cabinet.hasSetAllergyProfile {
            scannedMedicine = medicine
        }
    }

    private var homeContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                Text(headline)
                    .font(PETheme.display(33))
                    .foregroundStyle(PETheme.textPrimary)
                    .lineSpacing(2)
                    .contentTransition(.numericText())

                searchBar

                if let med = heroMedicine {
                    doseCard(med)
                        .id(med.id)
                        .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.98)), removal: .opacity))
                }

                pinnedRail
            }
            .padding(.horizontal, 22)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
    }

    // MARK: Header

    private var greeting: String { Self.greeting(for: profileName) }

    static func greeting(for profileName: String) -> String {
        let hour = Calendar.current.component(.hour, from: .now)
        let part = hour < 12 ? "Good morning" : hour < 17 ? "Good afternoon" : "Good evening"
        let first = profileName.split(separator: " ").first.map(String.init) ?? ""
        return first.isEmpty ? part : "\(part), \(first)"
    }

    private var headline: String {
        let left = cabinet.dosesLeftToday
        switch left {
        case 0: return "All done\nfor today."
        case 1: return "One dose left\ntoday."
        default:
            let f = NumberFormatter(); f.numberStyle = .spellOut
            let word = (f.string(from: left as NSNumber) ?? "\(left)").capitalized
            return "\(word) doses left\ntoday."
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text(Date.now, format: .dateTime.weekday(.wide).day().month(.abbreviated))
                    .font(PETheme.semibold(12.5)).foregroundStyle(PETheme.textTertiary)
                Text(greeting)
                    .font(PETheme.bold(19)).foregroundStyle(PETheme.textPrimary)
            }
            Spacer()
            HStack(spacing: 9) {
                Button { showScanner = true } label: { PEHeaderIconButton(systemImage: "barcode.viewfinder", square: true) }
                NavigationLink { NotificationsView() } label: {
                    PEHeaderIconButton(systemImage: "bell.fill", badge: true)
                }
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            NavigationLink { SearchView() } label: {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(PETheme.textTertiary)
                    Text("Search a medicine or symptom")
                        .font(PETheme.body(14)).foregroundStyle(PETheme.textTertiary)
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            // "Search object" = point the camera at a box instead of typing.
            Button { showScanner = true } label: {
                Text("Search object")
                    .font(PETheme.bold(12.5)).foregroundStyle(PETheme.onMar)
                    .padding(.horizontal, 15).padding(.vertical, 11)
                    .background(PETheme.mar, in: Capsule())
            }
        }
        .padding(.leading, 16).padding(6)
        .peSurface(PETheme.card, radius: PETheme.radiusPill)
    }

    // MARK: Dose card

    /// Selected medicine if it still exists, else the first one with a dose still to take.
    private var heroMedicine: Medicine? {
        if let id = selectedID, let med = cabinet.medicines.first(where: { $0.id == id }) { return med }
        let scheduled = cabinet.medicines.filter { !$0.isPRN && $0.finishedOn == nil }
        return scheduled.first { !cabinet.allTakenToday($0) } ?? scheduled.first ?? cabinet.medicines.first
    }

    private func pendingReminder(for med: Medicine) -> ReminderTime? {
        cabinet.pendingReminder(for: med)
    }

    private func timing(for med: Medicine) -> (text: String, tone: PEBadge.Tone) {
        if med.isPRN { return ("As needed", .mute) }
        guard let r = pendingReminder(for: med) else { return ("Done today", .green) }
        let mins = Int(r.time.timeIntervalSinceNow / 60)
        switch MissedDoseEngine.status(for: r, isPRN: false, loggedAt: nil) {
        case .missed: return ("Missed", .rose)
        case .dueSoon: return (mins > 0 ? "in \(mins) min" : "Due now", .gold)
        default:
            return (mins < 60 ? "in \(mins) min" : "in \(mins / 60)h \(mins % 60)m", .gold)
        }
    }

    private func doseCard(_ med: Medicine) -> some View {
        let reminder = pendingReminder(for: med)
        let timing = timing(for: med)
        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 13) {
                Circle().fill(PETheme.mar.opacity(0.18))
                    .frame(width: 48, height: 48)
                    .overlay(Image(systemName: med.isPRN ? "lungs.fill" : "pill.fill").foregroundStyle(PETheme.mar2))
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(med.name) \(med.strength)").font(PETheme.bold(17.5)).foregroundStyle(PETheme.textPrimary)
                    Text(med.composition).font(PETheme.body(12.5)).foregroundStyle(PETheme.textTertiary).lineLimit(1)
                }
                Spacer()
                PEBadge(text: timing.text, tone: timing.tone)
            }
            HStack(spacing: 8) {
                if med.isPRN {
                    metaPill(icon: "hand.tap", text: "When needed")
                    metaPill(icon: "pills", text: med.doseAmount ?? "1 dose")
                    metaPill(icon: "shippingbox", text: "\(med.dosesLeft) left")
                } else {
                    let r = reminder ?? cabinet.nextReminder(for: med)
                    metaPill(icon: "clock", text: r?.time.formatted(date: .omitted, time: .shortened) ?? "—")
                    metaPill(icon: "pills", text: med.doseAmount ?? "1 tablet")
                    metaPill(icon: "info.circle", text: r?.label ?? "—")
                }
            }
            HStack(spacing: 10) {
                NavigationLink { MedicineDetailView(medicine: med) } label: {
                    Text("Details")
                }.buttonStyle(PESecondaryButtonStyle())
                if med.isPRN {
                    Button("Log a dose") { withAnimation(.snappy) { cabinet.logPRNDose(med) } }
                        .buttonStyle(PEPrimaryButtonStyle())
                        .disabled(med.dosesLeft == 0)
                } else if let reminder {
                    Button("Mark Taken") { withAnimation(.snappy) { cabinet.markTaken(med, reminder: reminder) } }
                        .buttonStyle(PEPrimaryButtonStyle())
                } else {
                    Button("All taken") {}
                        .buttonStyle(PEPrimaryButtonStyle())
                        .disabled(true)
                }
            }
        }
        .padding(20)
        .peSurface(PETheme.card, radius: PETheme.radiusCardLg)
    }

    private func metaPill(icon: String, text: String) -> some View {
        Label(text, systemImage: icon)
            .font(PETheme.semibold(12.5)).foregroundStyle(PETheme.textSecondary)
            .lineLimit(1).minimumScaleFactor(0.8)
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(PETheme.card2, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: Pinned rail

    private func pinnedBadge(for med: Medicine) -> (String, PEBadge.Tone) {
        if med.isPRN { return ("As needed", .mute) }
        if cabinet.allTakenToday(med) { return ("Done", .green) }
        switch cabinet.status(for: med) {
        case .missed: return ("Missed", .rose)
        case .dueSoon: return ("Due", .gold)
        default: return ("Active", .green)
        }
    }

    private var pinnedRail: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Pinned medicines").font(PETheme.bold(11)).foregroundStyle(PETheme.textTertiary).textCase(.uppercase)
                Spacer()
                NavigationLink("See all") { CabinetView(showsBack: true) }
                    .font(PETheme.semibold(12.5)).foregroundStyle(PETheme.mar2)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(cabinet.medicines) { med in
                        let isShown = med.id == heroMedicine?.id
                        let badge = pinnedBadge(for: med)
                        Button {
                            withAnimation(.snappy(duration: 0.3)) { selectedID = med.id }
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(med.name).font(PETheme.bold(14.5)).foregroundStyle(PETheme.textPrimary)
                                Text("\(med.strength) · \(med.isPRN ? "as needed" : "\(med.dosesPerDay)× daily")")
                                    .font(PETheme.body(11.5)).foregroundStyle(PETheme.textTertiary)
                                Spacer(minLength: 10)
                                PEBadge(text: badge.0, tone: badge.1)
                            }
                            .padding(15)
                            .frame(width: 166, height: 110, alignment: .topLeading)
                            .peSurface(isShown ? PETheme.card2 : PETheme.card, radius: 22, seed: med.name.count,
                                       stroke: isShown ? PETheme.mar : PETheme.line2)
                            .overlay(alignment: .topTrailing) {
                                if isShown {
                                    Image(systemName: "eye.fill").font(.system(size: 11))
                                        .foregroundStyle(PETheme.mar2).padding(12)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(med.name) \(med.strength), \(badge.0)")
                        .accessibilityHint("Shows it in the dose card above")
                        .accessibilityAddTraits(isShown ? .isSelected : [])
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}


/// 05a — first-run Home, shown when the cabinet is empty (fixes "no empty states anywhere").
struct HomeFirstRunView: View {
    @Binding var showScanner: Bool
    @AppStorage("profile.name") private var profileName = ""
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(Date.now, format: .dateTime.weekday(.wide).day().month(.abbreviated))
                            .font(PETheme.semibold(12.5)).foregroundStyle(PETheme.textTertiary)
                        Text(HomeView.greeting(for: profileName)).font(PETheme.bold(19)).foregroundStyle(PETheme.textPrimary)
                    }
                    Spacer()
                    Button { showScanner = true } label: { PEHeaderIconButton(systemImage: "barcode.viewfinder", square: true) }
                }
                Text("Nothing tracked\nyet.").font(PETheme.display(33)).accessibilityAddTraits(.isHeader).foregroundStyle(PETheme.textPrimary).lineSpacing(2)

                VStack(spacing: 14) {
                    Image(systemName: "barcode.viewfinder")
                        .font(.system(size: 22)).foregroundStyle(PETheme.mar2)
                        .frame(width: 52, height: 52)
                        .background(PETheme.mar.opacity(0.14), in: RoundedRectangle(cornerRadius: 16))
                    Text("Scan your first medicine").font(PETheme.bold(16)).foregroundStyle(PETheme.textPrimary)
                    Text("We'll build your schedule and cabinet from the box automatically.")
                        .font(PETheme.prose(14)).foregroundStyle(PETheme.textSecondary)
                        .multilineTextAlignment(.center)
                    Button("Scan a medicine") { showScanner = true }
                        .buttonStyle(PEPrimaryButtonStyle())
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .background(RoundedRectangle(cornerRadius: 26).strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5])).foregroundStyle(PETheme.line2))

                VStack(alignment: .leading, spacing: 4) {
                    Text("BEFORE YOU START").font(PETheme.bold(11)).foregroundStyle(PETheme.textTertiary)
                    infoRow(icon: "lock.fill", title: "Everything stays on this phone", subtitle: "Nothing syncs anywhere unless you turn it on.")
                    infoRow(icon: "info.circle.fill", title: "Informational only", subtitle: "PharmEye never replaces a doctor or pharmacist.")
                }
            }
            .padding(.horizontal, 22).padding(.top, 8)
        }
    }

    private func infoRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 13) {
            Image(systemName: icon).foregroundStyle(PETheme.textSecondary)
                .frame(width: 40, height: 40).background(PETheme.card3, in: RoundedRectangle(cornerRadius: 13))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(PETheme.semibold(14)).foregroundStyle(PETheme.textPrimary)
                Text(subtitle).font(PETheme.prose(12.5)).foregroundStyle(PETheme.textTertiary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .peSurface(PETheme.card, radius: 20, seed: title.count)
    }
}
