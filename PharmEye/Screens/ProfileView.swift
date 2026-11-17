import SwiftUI

/// 10 — Profile. Every row opens its own page (Screens/Profile/ProfilePages.swift).
/// Includes the Terms & Conditions row added in the guidelines pass, and the Credit
/// section (a social nudge only — GPL-3.0 is the real enforcement).
struct ProfileView: View {
    @EnvironmentObject private var cabinet: CabinetStore
    @AppStorage("profile.name") private var name = ""
    @AppStorage("profile.age") private var age = ""
    @AppStorage("profile.gender") private var gender = ""
    @AppStorage("ai.provider") private var provider = "Gemini"
    @AppStorage("security.appLock") private var appLock = false
    @StateObject private var auth = AuthStore.shared
    @State private var showScanner = false

    private var initials: String {
        let parts = name.split(separator: " ").prefix(2).compactMap(\.first)
        return parts.isEmpty ? "?" : String(parts).uppercased()
    }

    private var detailsLine: String {
        let bits = [age.isEmpty ? nil : "Age \(age)", gender.isEmpty ? nil : gender].compactMap { $0 }
        return bits.isEmpty ? "Tap to add your details" : bits.joined(separator: " · ")
    }

    var body: some View {
        ZStack {
            PEPaperBackground()
            ScrollView {
                VStack(spacing: 22) {
                    HStack {
                        Spacer()
                        Button { showScanner = true } label: { PEHeaderIconButton(systemImage: "barcode.viewfinder", square: true) }
                        NavigationLink { NotificationsView() } label: { PEHeaderIconButton(systemImage: "bell.fill", badge: true) }
                    }

                    NavigationLink { PersonalDetailsPage() } label: {
                        VStack(spacing: 6) {
                            Circle()
                                .fill(PETheme.mar)
                                .frame(width: 88, height: 88)
                                .overlay(Text(initials).font(PETheme.display(30)).foregroundStyle(PETheme.onMar))
                                .overlay(PESketchRect(cornerRadius: 44, seed: 2).stroke(PETheme.textPrimary, lineWidth: 1.3))
                            Text(name.isEmpty ? "Your profile" : name).font(PETheme.display(24)).accessibilityAddTraits(.isHeader).foregroundStyle(PETheme.textPrimary)
                            HStack(spacing: 4) {
                                Text(detailsLine)
                                Image(systemName: "pencil").font(.system(size: 10, weight: .semibold))
                            }
                            .font(PETheme.body(12.5)).foregroundStyle(PETheme.textTertiary)
                        }
                    }
                    .buttonStyle(.plain)

                    HStack(spacing: 0) {
                        let today = cabinet.takenToday
                        stat("\(cabinet.medicines.count)", "MEDICINES")
                        Divider().frame(height: 36).overlay(PETheme.line)
                        stat("\(today.taken)/\(today.scheduled)", "TAKEN TODAY")
                        Divider().frame(height: 36).overlay(PETheme.line)
                        stat("\(cabinet.activeReminderCount)", "REMINDERS")
                    }
                    .padding(.vertical, 16)
                    .peSurface(PETheme.card, radius: 22)

                    group("Account") {
                        row("person.crop.circle.fill", "Account",
                            auth.session.map { $0.email ?? "Signed in with Apple" } ?? "Not signed in") { AccountPage() }
                    }

                    group("Health record") {
                        row("doc.text.fill", "Conditions & allergies", allergySummary) { ConditionsAllergiesPage() }
                        row("person.2.fill", "Care team", careTeamSummary) { CareTeamPage() }
                        row("calendar", "Schedule & reminders", "\(cabinet.activeReminderCount) reminders active") {
                            NotificationsView(initialTab: .reminders)
                        }
                        row("mic.fill", "Siri & Shortcuts", "Log doses and check your schedule by voice") {
                            SiriShortcutsPage()
                        }
                    }

                    group("AI & security") {
                        row("key.fill", "AI provider key",
                            Keychain.get(account: Keychain.aiKeyAccount) == nil ? "Not set" : "\(provider) · stored in Keychain") {
                            AIProviderPage()
                        }
                        row("faceid", "Face ID unlock", appLock ? "On · asked every time the app opens" : "Off") { AppLockPage() }
                        row("checkmark.shield.fill", "Two-factor authentication", "Not needed: data stays on this phone") {
                            SwitchedOffPage(title: "Two-factor authentication",
                                explanation: "Your medicines and health details live only on this phone, not in an online account, so there's no cloud data for two-factor to protect. Use Face ID unlock to keep them private.")
                        }
                        row("icloud.fill", "Backup", "Export a copy of your data") {
                            SwitchedOffPage(title: "Backup",
                                explanation: "PharmEye doesn't upload your cabinet anywhere, so there's no cloud backup. You can export a copy of your data at any time and keep it wherever you like.")
                        }
                    }

                    group("Legal") {
                        row("doc.text.fill", "Terms & Conditions", "Last updated 6 Nov 2026") {
                            LegalDocumentPage(title: "Terms & Conditions", updated: "6 Nov 2026", sections: LegalText.terms)
                        }
                        row("lock.doc.fill", "Privacy Policy", "What we collect and why") {
                            LegalDocumentPage(title: "Privacy Policy", updated: "6 Nov 2026", sections: LegalText.privacy)
                        }
                        row("exclamationmark.triangle.fill", "Medical disclaimer", "Informational only · not a diagnosis") {
                            LegalDocumentPage(title: "Medical disclaimer", updated: "6 Nov 2026", sections: LegalText.disclaimer)
                        }
                        row("square.and.arrow.up", "Export or delete my data", "GDPR & UAE data rights") { DataRightsPage() }
                        row("doc.plaintext.fill", "Open-source licences", "GPL-3.0 · Poppins · Lora") { LicencesPage() }
                    }

                    VStack(alignment: .leading, spacing: 0) {
                        Text("CREDIT").font(PETheme.bold(11)).foregroundStyle(PETheme.textTertiary)
                            .padding(.bottom, 12)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(spacing: 9) {
                        HStack(spacing: 6) {
                            Image(systemName: "lock.fill").font(.system(size: 10))
                            Text("PROTECTED SECTION").font(PETheme.bold(10)).kerning(1)
                        }
                        .foregroundStyle(PETheme.textTertiary)
                        Text("**PharmEye** — designed and built by **Anas Aslam**.\nReleased under GPL-3.0. © 2026 Anas Aslam.")
                            .font(PETheme.body(12.5)).foregroundStyle(PETheme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity)
                    .peSurface(PETheme.card, radius: 20)

                    Text("PharmEye 1.0 · stored on this phone only\nInformation is educational and never replaces a clinician.")
                        .font(PETheme.body(11)).foregroundStyle(PETheme.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 30)
                }
                .padding(.horizontal, 22).padding(.top, 4)
            }
        }
        .toolbar(.hidden)
        .sheet(isPresented: $showScanner) {
            ScannerView { cabinet.addScannedMedicine($0) }
        }
    }

    private var allergySummary: String {
        let a = cabinet.allergies.count, c = cabinet.conditions.isEmpty ? 0 : 1
        if a == 0 && c == 0 { return "None added" }
        let allergyText = a == 1 ? "\(cabinet.allergies.first!) allergy" : "\(a) allergies"
        return a == 0 ? "1 condition noted" : c == 0 ? allergyText : "\(allergyText) · conditions noted"
    }

    private var careTeamSummary: String {
        guard let first = cabinet.careTeam.first else { return "No contacts yet" }
        let more = cabinet.careTeam.count - 1
        return more > 0 ? "\(first.name) + \(more) more" : [first.name, first.role].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(PETheme.display(19)).foregroundStyle(PETheme.textPrimary)
            Text(label).font(PETheme.bold(10)).foregroundStyle(PETheme.textTertiary)
        }.frame(maxWidth: .infinity)
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title.uppercased()).font(PETheme.bold(11)).foregroundStyle(PETheme.textTertiary)
                .padding(.bottom, 12)
            VStack(spacing: 0, content: content)
                .peSurface(PETheme.card, radius: 22)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row<Destination: View>(_ icon: String, _ title: String, _ subtitle: String,
                                        @ViewBuilder destination: @escaping () -> Destination) -> some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 13) {
                Image(systemName: icon).foregroundStyle(PETheme.textSecondary)
                    .frame(width: 36, height: 36).background(PETheme.card3, in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(PETheme.semibold(14)).foregroundStyle(PETheme.textPrimary)
                    Text(subtitle).font(PETheme.body(11.5)).foregroundStyle(PETheme.textTertiary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(PETheme.textTertiary)
            }
            .padding(15)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) { Rectangle().fill(PETheme.line).frame(height: 1).padding(.leading, 65) }
        }
        .buttonStyle(.plain)
    }
}
