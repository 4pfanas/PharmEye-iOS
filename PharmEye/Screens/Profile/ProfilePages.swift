import SwiftUI
import LocalAuthentication
import AppIntents

// MARK: - Page scaffold

/// Shared shell for every Profile sub-page: paper background, back button, title.
struct PEPage<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var content: Content
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            PEPaperBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Button { dismiss() } label: { PEHeaderIconButton(systemImage: "chevron.left") }
                    VStack(alignment: .leading, spacing: 6) {
                        Text(title).font(PETheme.display(27)).accessibilityAddTraits(.isHeader).foregroundStyle(PETheme.textPrimary)
                        if let subtitle {
                            Text(subtitle).font(PETheme.prose(14.5)).foregroundStyle(PETheme.textSecondary)
                        }
                    }
                    content
                }
                .padding(.horizontal, 22).padding(.top, 4).padding(.bottom, 40)
            }
        }
        .toolbar(.hidden)
    }
}

/// Small labelled section used across the pages.
struct PESection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title.uppercased()).font(PETheme.bold(11)).foregroundStyle(PETheme.textTertiary)
            content
        }
        .padding(.top, 4)
    }
}

/// A sand card holding a block of explanatory text.
struct PENote: View {
    var icon: String = "info.circle.fill"
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).foregroundStyle(PETheme.mar2).padding(.top, 1)
            Text(text).font(PETheme.body(12.5)).foregroundStyle(PETheme.textSecondary).lineSpacing(2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .peSurface(PETheme.card, radius: 16, seed: text.count)
    }
}

// MARK: - Personal details

struct PersonalDetailsPage: View {
    @AppStorage("profile.name") private var name = ""
    @AppStorage("profile.age") private var age = ""
    @AppStorage("profile.gender") private var gender = ""
    private let genders = ["Male", "Female", "Prefer not to say"]

    var body: some View {
        PEPage(title: "Personal details", subtitle: "Used to personalise the app. Stored only on this phone.") {
            PESection(title: "Full name") { TextField("Your name", text: $name).textFieldStyle(PEFieldStyle()) }
            PESection(title: "Age") { TextField("Optional", text: $age).keyboardType(.numberPad).textFieldStyle(PEFieldStyle()) }
            PESection(title: "Gender") {
                HStack(spacing: 8) {
                    ForEach(genders, id: \.self) { g in
                        Text(g)
                            .font(PETheme.semibold(13.5))
                            .foregroundStyle(gender == g ? PETheme.onMar : PETheme.textSecondary)
                            .lineLimit(1).fixedSize()
                            .padding(.horizontal, 14).padding(.vertical, 11)
                            .peSurface(gender == g ? PETheme.mar : PETheme.card, radius: PETheme.radiusPill, seed: g.count,
                                       stroke: gender == g ? PETheme.textPrimary : PETheme.line2)
                            .peChipTraits(selected: gender == g)
                            .onTapGesture { gender = g }
                    }
                }
            }
            PENote(icon: "checkmark.circle.fill", text: "Changes save as you type.")
        }
    }
}

// MARK: - Conditions & allergies

struct ConditionsAllergiesPage: View {
    @EnvironmentObject private var cabinet: CabinetStore
    @State private var newAllergy = ""
    private let common = ["Penicillin", "Sulfa drugs", "Aspirin", "Ibuprofen", "Latex"]

    var body: some View {
        PEPage(title: "Conditions & allergies",
               subtitle: "PharmEye checks every medicine you add against this list.") {
            PESection(title: "Allergies") {
                FlowChips(options: Array(Set(common).union(cabinet.allergies)).sorted(), selected: $cabinet.allergies)
                HStack(spacing: 8) {
                    TextField("Add another allergy", text: $newAllergy)
                        .textFieldStyle(PEFieldStyle())
                        .onSubmit(addAllergy)
                    Button(action: addAllergy) { PEHeaderIconButton(systemImage: "plus") }
                        .disabled(newAllergy.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            PESection(title: "Ongoing conditions") {
                TextField("e.g. asthma, type 2 diabetes", text: $cabinet.conditions, axis: .vertical)
                    .lineLimit(3...6)
                    .textFieldStyle(PEFieldStyle())
            }
            PENote(icon: "lock.fill", text: "Saved on this phone only. Tap an allergy to switch it on or off.")
        }
    }

    private func addAllergy() {
        let a = newAllergy.trimmingCharacters(in: .whitespaces)
        guard !a.isEmpty else { return }
        cabinet.allergies.insert(a.capitalized)
        newAllergy = ""
    }
}

// MARK: - Care team

struct CareTeamPage: View {
    /// First letter of the name, skipping a title like "Dr." so "Dr. Meera Nair" shows "M".
    static func initial(of name: String) -> String {
        let titles: Set<String> = ["dr", "dr.", "mr", "mr.", "mrs", "mrs.", "ms", "ms.", "prof", "prof."]
        let words = name.split(separator: " ").filter { !titles.contains($0.lowercased()) }
        return String((words.first ?? Substring(name)).prefix(1)).uppercased()
    }

    @EnvironmentObject private var cabinet: CabinetStore
    @State private var editing: CareContact?

    var body: some View {
        PEPage(title: "Care team", subtitle: "Your doctors, pharmacist and carers, one tap away.") {
            if cabinet.careTeam.isEmpty {
                PENote(icon: "person.2.fill", text: "No one added yet. Add your GP or pharmacist so you can call them straight from here.")
            }
            ForEach(cabinet.careTeam) { contact in
                HStack(spacing: 13) {
                    Text(Self.initial(of: contact.name))
                        .font(PETheme.bold(16)).foregroundStyle(PETheme.onMar)
                        .frame(width: 42, height: 42).background(PETheme.mar, in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(contact.name).font(PETheme.semibold(14.5)).foregroundStyle(PETheme.textPrimary)
                        Text([contact.role, contact.phone].filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(PETheme.body(12)).foregroundStyle(PETheme.textTertiary)
                    }
                    Spacer()
                    if let url = URL(string: "tel:\(contact.phone.filter { $0.isNumber || $0 == "+" })"), !contact.phone.isEmpty {
                        Link(destination: url) { PEHeaderIconButton(systemImage: "phone.fill") }
                    }
                    Button { editing = contact } label: { PEHeaderIconButton(systemImage: "pencil") }
                }
                .padding(14)
                .peSurface(PETheme.card, radius: 20, seed: contact.name.count)
            }
            Button("Add a contact") { editing = CareContact(name: "", role: "", phone: "") }
                .buttonStyle(PEPrimaryButtonStyle()).padding(.top, 4)
        }
        .sheet(item: $editing) { contact in
            CareContactEditor(contact: contact)
        }
    }
}

private struct CareContactEditor: View {
    @EnvironmentObject private var cabinet: CabinetStore
    @Environment(\.dismiss) private var dismiss
    @State var contact: CareContact
    private var isNew: Bool { !cabinet.careTeam.contains { $0.id == contact.id } }

    var body: some View {
        PEPage(title: isNew ? "New contact" : "Edit contact") {
            PESection(title: "Name") { TextField("Dr. Meera Nair", text: $contact.name).textFieldStyle(PEFieldStyle()) }
            PESection(title: "Role") { TextField("GP, pharmacist, carer…", text: $contact.role).textFieldStyle(PEFieldStyle()) }
            PESection(title: "Phone") {
                TextField("+971 …", text: $contact.phone).keyboardType(.phonePad).textFieldStyle(PEFieldStyle())
            }
            Button("Save") {
                if let i = cabinet.careTeam.firstIndex(where: { $0.id == contact.id }) {
                    cabinet.careTeam[i] = contact
                } else {
                    cabinet.careTeam.append(contact)
                }
                dismiss()
            }
            .buttonStyle(PEPrimaryButtonStyle())
            .disabled(contact.name.trimmingCharacters(in: .whitespaces).isEmpty)
            if !isNew {
                Button("Remove from care team") {
                    cabinet.careTeam.removeAll { $0.id == contact.id }
                    dismiss()
                }
                .buttonStyle(PESecondaryButtonStyle())
            }
        }
    }
}

// MARK: - AI provider key

struct AIProviderPage: View {
    @AppStorage("ai.provider") private var provider = "Gemini"
    @State private var key = ""
    @State private var hasKey = Keychain.get(account: Keychain.aiKeyAccount) != nil
    @State private var saved = false
    private let providers = ["Gemini", "Claude", "OpenAI"]

    var body: some View {
        PEPage(title: "AI provider key",
               subtitle: "Bring your own key for the symptom check. PharmEye never sees or stores it anywhere but this phone's Keychain.") {
            PESection(title: "Provider") {
                HStack(spacing: 8) {
                    ForEach(providers, id: \.self) { p in
                        Text(p)
                            .font(PETheme.semibold(13.5))
                            .foregroundStyle(provider == p ? PETheme.onMar : PETheme.textSecondary)
                            .padding(.horizontal, 16).padding(.vertical, 11)
                            .peSurface(provider == p ? PETheme.mar : PETheme.card, radius: PETheme.radiusPill, seed: p.count,
                                       stroke: provider == p ? PETheme.textPrimary : PETheme.line2)
                            .peChipTraits(selected: provider == p)
                            .onTapGesture { provider = p }
                    }
                }
            }
            PESection(title: "API key") {
                SecureField(hasKey ? "•••••••• saved — paste to replace" : "Paste your key", text: $key)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .textFieldStyle(PEFieldStyle())
            }
            Button(saved ? "Saved to Keychain" : "Save key") {
                Keychain.set(key.trimmingCharacters(in: .whitespacesAndNewlines), account: Keychain.aiKeyAccount)
                key = ""; hasKey = true; saved = true
            }
            .buttonStyle(PEPrimaryButtonStyle())
            .disabled(key.trimmingCharacters(in: .whitespaces).isEmpty)
            if hasKey {
                Button("Remove key") {
                    Keychain.delete(account: Keychain.aiKeyAccount)
                    hasKey = false; saved = false
                }
                .buttonStyle(PESecondaryButtonStyle())
            }
            PENote(icon: "exclamationmark.shield.fill",
                   text: "When you run a symptom check, what you type is sent to \(provider) using this key. Nothing else from your cabinet or profile is sent.")
        }
    }
}

// MARK: - Security

/// Real Face ID / passcode lock. Turning it on needs one successful unlock first, so
/// nobody can lock themselves out with a device that has no biometrics or passcode.
struct AppLockPage: View {
    @AppStorage("security.appLock") private var appLock = false
    @State private var error: String?

    var body: some View {
        PEPage(title: "Face ID unlock", subtitle: "Ask for Face ID (or your passcode) every time PharmEye opens.") {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Require Face ID").font(PETheme.semibold(14.5)).foregroundStyle(PETheme.textPrimary)
                    Text(appLock ? "On" : "Off").font(PETheme.body(12)).foregroundStyle(PETheme.textTertiary)
                }
                Spacer()
                Toggle("", isOn: Binding(get: { appLock }, set: { setLock($0) }))
                    .labelsHidden().tint(PETheme.mar)
            }
            .padding(15)
            .peSurface(PETheme.card, radius: 20)
            if let error { PENote(icon: "exclamationmark.triangle.fill", text: error) }
            PENote(text: "Your medicines and health details are already stored on this phone only. The lock stops someone who picks up your unlocked phone from reading them.")
        }
    }

    private func setLock(_ on: Bool) {
        guard on else { appLock = false; return }
        AppLock.authenticate(reason: "Turn on Face ID unlock for PharmEye") { ok, message in
            appLock = ok
            error = ok ? nil : message
        }
    }
}

enum AppLock {
    static func authenticate(reason: String, completion: @escaping @MainActor (Bool, String?) -> Void) {
        let context = LAContext()
        var err: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err) else {
            Task { @MainActor in completion(false, "Set up Face ID or a passcode on this iPhone first.") }
            return
        }
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { ok, error in
            Task { @MainActor in completion(ok, ok ? nil : (error?.localizedDescription ?? "Couldn't verify it's you.")) }
        }
    }
}

/// Covers the app with a lock screen while `security.appLock` is on and the user
/// hasn't unlocked since the app last went to the background.
struct AppLockGate: ViewModifier {
    @AppStorage("security.appLock") private var appLock = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var unlocked = false

    func body(content: Content) -> some View {
        content
            .overlay {
                if appLock && !unlocked {
                    ZStack {
                        PEPaperBackground()
                        VStack(spacing: 18) {
                            LogoMark().frame(width: 80, height: 80)
                            Text("PharmEye is locked").font(PETheme.display(24)).accessibilityAddTraits(.isHeader).foregroundStyle(PETheme.textPrimary)
                            Button("Unlock") { unlock() }
                                .buttonStyle(PEPrimaryButtonStyle()).padding(.horizontal, 60)
                        }
                    }
                    .transition(.opacity)
                    .onAppear(perform: unlock)
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background { unlocked = false }
            }
    }

    private func unlock() {
        AppLock.authenticate(reason: "Unlock PharmEye") { ok, _ in
            withAnimation { unlocked = ok }
        }
    }
}

struct SwitchedOffPage: View {
    let title: String
    let explanation: String
    var body: some View {
        PEPage(title: title) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(PETheme.semibold(14.5)).foregroundStyle(PETheme.textPrimary)
                    Text("Off").font(PETheme.body(12)).foregroundStyle(PETheme.textTertiary)
                }
                Spacer()
                Toggle("", isOn: .constant(false)).labelsHidden().disabled(true)
            }
            .padding(15)
            .peSurface(PETheme.card, radius: 20)
            PENote(text: explanation)
            NavigationLink("Export a copy of my data") { DataRightsPage() }
                .buttonStyle(PESecondaryButtonStyle())
        }
    }
}

// MARK: - Legal

struct LegalDocumentPage: View {
    let title: String
    let updated: String
    let sections: [(heading: String, body: String)]

    var body: some View {
        PEPage(title: title, subtitle: "Last updated \(updated)") {
            ForEach(sections.indices, id: \.self) { i in
                VStack(alignment: .leading, spacing: 6) {
                    Text(sections[i].heading).font(PETheme.bold(15)).foregroundStyle(PETheme.textPrimary)
                    Text(sections[i].body).font(PETheme.prose(14.5)).foregroundStyle(PETheme.textSecondary).lineSpacing(3)
                }
                .padding(.top, 6)
            }
        }
    }
}

enum LegalText {
    static let terms: [(heading: String, body: String)] = [
        ("Using PharmEye", "PharmEye helps you keep track of the medicines you take, when to take them and whether you took them. It is a personal organiser, not a medical service."),
        ("Not medical advice", "Everything PharmEye shows — leaflet summaries, interaction notes, symptom matches — is general information. Always follow your doctor's or pharmacist's instructions over anything in the app."),
        ("Your responsibilities", "You're responsible for entering your medicines and schedule correctly and for keeping your phone's notifications switched on if you rely on reminders."),
        ("Licence", "PharmEye is free software released under the GNU General Public License v3.0. You may use, study, share and modify it under that licence's terms."),
        ("Changes", "If these terms change, the app will show the new date at the top of this page.")
    ]

    static let privacy: [(heading: String, body: String)] = [
        ("What stays on your phone", "Your cabinet, schedule, doses, allergies, conditions and care team are stored only on this phone. They are never uploaded."),
        ("Your account (optional)", "If you sign in with Apple, Google or email, our sign-in provider (Supabase) stores your email address and a sign-in record so you can get back into your account. With Sign in with Apple you can hide your real email. You can use PharmEye without an account."),
        ("What else leaves your phone", "Only if you set it up: when you run a symptom check with your own AI provider key, the symptoms you type are sent to that provider to get a result. Their privacy policy applies to that request."),
        ("Reminders", "Dose reminders and the Dynamic Island countdown are handled by iOS on this device. They work offline and are never sent anywhere."),
        ("Your rights", "You can export everything PharmEye stores, or delete it all, from Profile → Export or delete my data. Deleting also signs you out. To delete your account itself, contact us and we'll remove it."),
        ("Security", "Data stays inside PharmEye's private storage. Your sign-in and AI key are kept in the iOS Keychain, and you can require Face ID to open the app.")
    ]

    static let disclaimer: [(heading: String, body: String)] = [
        ("Informational only", "PharmEye does not diagnose, treat or prevent any condition. Symptom matches are rough likelihoods, not a diagnosis."),
        ("Interactions and allergies", "Interaction and allergy warnings currently cover a limited set of medicines. No warning does not mean a combination is safe — check with your pharmacist."),
        ("Emergencies", "If you think you've taken too much of a medicine, have a severe reaction, or feel seriously unwell, call 998 (UAE ambulance) or your local emergency number straight away."),
        ("Missed doses", "PharmEye will never tell you to double a dose. If you miss one, follow the leaflet or ask your pharmacist.")
    ]
}

// MARK: - Export / delete

struct DataRightsPage: View {
    @EnvironmentObject private var cabinet: CabinetStore
    @State private var exportURL: URL?
    @State private var confirmDelete = false
    @State private var deleted = false

    var body: some View {
        PEPage(title: "Export or delete my data",
               subtitle: "Everything PharmEye stores lives on this phone. Take a copy, or wipe it.") {
            PESection(title: "Export") {
                PENote(icon: "doc.text.fill", text: "A JSON file with your medicines, schedule, allergies, conditions and care team. Your AI key is never included.")
                if let exportURL {
                    ShareLink(item: exportURL) {
                        Label("Share export file", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(PEPrimaryButtonStyle())
                }
            }
            PESection(title: "Delete") {
                PENote(icon: "trash.fill", text: "Removes every medicine, reminder, health detail, care contact and your saved AI key, and signs you out. This can't be undone.")
                Button(deleted ? "Everything deleted" : "Delete all my data") { confirmDelete = true }
                    .buttonStyle(PESecondaryButtonStyle())
                    .foregroundStyle(PETheme.rose)
                    .disabled(deleted)
            }
        }
        .onAppear(perform: writeExport)
        .confirmationDialog("Delete all PharmEye data?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete everything", role: .destructive) {
                cabinet.deleteAllData()
                deleted = true
                writeExport()
            }
        } message: {
            Text("Your cabinet, reminders and health profile will be removed from this phone.")
        }
    }

    private func writeExport() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("PharmEye-export.json")
        try? cabinet.exportData().write(to: url)
        exportURL = url
    }
}

// MARK: - Licences

struct LicencesPage: View {
    var body: some View {
        PEPage(title: "Open-source licences", subtitle: "PharmEye is built on and released as open source.") {
            licenceRow("PharmEye", "GNU GPL v3.0") {
                LicenceTextPage(title: "PharmEye", text: "PharmEye — designed and built by Anas Aslam.\nCopyright © 2026 Anas Aslam.\n\nThis program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.\n\nThis program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details: https://www.gnu.org/licenses/gpl-3.0.html")
            }
            licenceRow("Poppins typeface", "SIL Open Font License 1.1") {
                LicenceTextPage(title: "Poppins", text: Self.bundled("OFL-Poppins"))
            }
            licenceRow("Lora typeface", "SIL Open Font License 1.1") {
                LicenceTextPage(title: "Lora", text: Self.bundled("OFL-Lora"))
            }
        }
    }

    private func licenceRow<Dest: View>(_ name: String, _ licence: String, @ViewBuilder destination: () -> Dest) -> some View {
        NavigationLink(destination: destination) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name).font(PETheme.semibold(14.5)).foregroundStyle(PETheme.textPrimary)
                    Text(licence).font(PETheme.body(12)).foregroundStyle(PETheme.textTertiary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(PETheme.textTertiary)
            }
            .padding(15)
            .peSurface(PETheme.card, radius: 18, seed: name.count)
        }
        .buttonStyle(.plain)
    }

    static func bundled(_ name: String) -> String {
        guard let url = Bundle.main.url(forResource: name, withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return "Licence text not found." }
        return text
    }
}

private struct LicenceTextPage: View {
    let title: String
    let text: String
    var body: some View {
        PEPage(title: title) {
            Text(text).font(.system(size: 12, design: .monospaced)).foregroundStyle(PETheme.textSecondary)
                .textSelection(.enabled)
        }
    }
}

// MARK: - Siri & Shortcuts

/// Shows people what they can say. The phrases themselves live in PharmEyeShortcuts.
struct SiriShortcutsPage: View {
    var body: some View {
        PEPage(title: "Siri & Shortcuts",
               subtitle: "Log doses and check your schedule hands-free. Every phrase ends in “in PharmEye”.") {
            PESection(title: "Try saying") {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Self.phrases, id: \.self) { phrase in
                        HStack(spacing: 12) {
                            Image(systemName: "mic.fill").foregroundStyle(PETheme.mar2).accessibilityHidden(true)
                            Text("“\(phrase)”").font(PETheme.semibold(14)).foregroundStyle(PETheme.textPrimary)
                            Spacer()
                        }
                        .padding(14)
                        .overlay(alignment: .bottom) { Rectangle().fill(PETheme.line).frame(height: 1) }
                    }
                }
                .peSurface(PETheme.card, radius: 20)
            }
            PESection(title: "Shortcuts app") {
                ShortcutsLink()
                    .shortcutsLinkStyle(.automaticOutline)
            }
            PENote(icon: "lock.fill", text: "Siri only reads from the cabinet on this phone. Nothing is sent to PharmEye or anyone else.")
        }
    }

    static let phrases = [
        "Hey Siri, what's my next dose in PharmEye",
        "Hey Siri, log my Metformin in PharmEye",
        "Hey Siri, did I take my Augmentin in PharmEye",
        "Hey Siri, log a dose in PharmEye"
    ]
}

// MARK: - Account

struct AccountPage: View {
    @StateObject private var auth = AuthStore.shared
    @State private var confirmSignOut = false

    var body: some View {
        PEPage(title: "Account", subtitle: auth.isSignedIn
               ? "Your sign-in. Your medicines and health details stay on this phone."
               : "Sign in so you can get back into PharmEye on a new phone.") {
            if let session = auth.session {
                HStack(spacing: 13) {
                    Image(systemName: providerIcon(session.provider))
                        .font(.system(size: 18)).foregroundStyle(PETheme.onMar)
                        .frame(width: 44, height: 44).background(PETheme.mar, in: Circle())
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.email ?? "Hidden Apple email").font(PETheme.semibold(14.5)).foregroundStyle(PETheme.textPrimary)
                        Text("Signed in with \(providerName(session.provider))").font(PETheme.body(12)).foregroundStyle(PETheme.textTertiary)
                    }
                    Spacer()
                }
                .padding(15)
                .peSurface(PETheme.card, radius: 20)
                .accessibilityElement(children: .combine)

                Button("Sign out") { confirmSignOut = true }
                    .buttonStyle(PESecondaryButtonStyle())
                PENote(text: "Signing out keeps your cabinet on this phone. Only the sign-in is removed.")
            } else {
                AuthOptions(onSignedIn: {})
            }
        }
        .confirmationDialog("Sign out of PharmEye?", isPresented: $confirmSignOut, titleVisibility: .visible) {
            Button("Sign out", role: .destructive) { auth.signOut() }
        }
    }

    private func providerName(_ p: String) -> String {
        switch p { case "apple": "Apple"; case "google": "Google"; default: "email" }
    }
    private func providerIcon(_ p: String) -> String {
        switch p { case "apple": "apple.logo"; case "google": "globe"; default: "envelope.fill" }
    }
}
