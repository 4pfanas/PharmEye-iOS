import AuthenticationServices
import SwiftUI

/// 03 — Sign in. Apple, Google and email accounts through Supabase, plus "continue
/// without an account" (App Review 4.8: third-party login needs an equivalent-privacy
/// alternative — Sign in with Apple satisfies this). Medicines stay on the phone either way.
struct SignInView: View {
    var onContinue: () -> Void
    var body: some View {
        ZStack {
            PEPaperBackground()
            ScrollView {
                VStack(spacing: 0) {
                    art.padding(.horizontal, 22)
                    VStack(spacing: 11) {
                        Text("Your health record\nstays yours")
                            .font(PETheme.display(30)).accessibilityAddTraits(.isHeader)
                            .foregroundStyle(PETheme.textPrimary).multilineTextAlignment(.center)
                        Text("Create an account to keep your profile safe if you change phones, or skip it. Your medicines stay on this phone either way.")
                            .font(PETheme.body(14.5)).foregroundStyle(PETheme.textSecondary).multilineTextAlignment(.center)
                    }
                    .padding(.top, 22).padding(.horizontal, 26).padding(.bottom, 26)

                    AuthOptions(onSignedIn: onContinue, onSkip: onContinue)
                        .padding(.horizontal, 22).padding(.bottom, 30)
                }
            }
        }
    }

    private var art: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(.clear)
                .peSurface(PETheme.card, radius: 32, seed: 17)
            LogoMark().frame(width: 96, height: 96).accessibilityHidden(true)
        }
        .frame(height: 230)
    }
}

/// The sign-in choices, shared by onboarding and Profile → Account.
struct AuthOptions: View {
    var onSignedIn: () -> Void
    var onSkip: (() -> Void)? = nil

    @StateObject private var auth = AuthStore.shared
    @AppStorage("profile.name") private var profileName = ""
    @Environment(\.colorScheme) private var colorScheme
    @State private var showEmail = false
    @State private var showLegal: LegalSheet?
    @State private var error: String?
    @State private var busy = false

    enum LegalSheet: String, Identifiable { case terms, privacy; var id: String { rawValue } }

    var body: some View {
        VStack(spacing: 12) {
            if !SupabaseConfig.isConfigured {
                PENote(icon: "wrench.and.screwdriver.fill",
                       text: "Accounts aren't connected in this build yet (add a Supabase.plist with your project URL and key). You can still use everything without one.")
            }

            SignInWithAppleButton(.continue) { request in
                auth.prepareAppleRequest(request)
            } onCompletion: { result in
                run {
                    if let name = try await auth.completeApple(result), profileName.isEmpty { profileName = name }
                }
            }
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: 54)
            .clipShape(Capsule())
            .disabled(!SupabaseConfig.isConfigured)
            .opacity(SupabaseConfig.isConfigured ? 1 : 0.45)

            Button { run { try await auth.signInWithGoogle() } } label: {
                HStack(spacing: 10) {
                    Text("G").font(.system(size: 19, weight: .bold, design: .rounded)).accessibilityHidden(true)
                    Text("Continue with Google")
                }
            }
            .buttonStyle(PEAuthButtonStyle())
            .disabled(!SupabaseConfig.isConfigured)

            Button { showEmail = true } label: {
                HStack(spacing: 10) { Image(systemName: "envelope.fill").accessibilityHidden(true); Text("Continue with email") }
            }
            .buttonStyle(PEAuthButtonStyle())
            .disabled(!SupabaseConfig.isConfigured)

            if let onSkip {
                Button("Continue without an account") { onSkip() }
                    .buttonStyle(PESecondaryButtonStyle())
            }

            if busy { ProgressView().tint(PETheme.mar).padding(.top, 4) }
            if let error { PENote(icon: "exclamationmark.triangle.fill", text: error) }

            HStack(spacing: 4) {
                Text("By continuing you agree to our")
                Button("Terms") { showLegal = .terms }.bold()
                Text("and")
                Button("Privacy Policy") { showLegal = .privacy }.bold()
            }
            .font(PETheme.body(11.5)).foregroundStyle(PETheme.textTertiary)
            .tint(PETheme.mar2)
            .multilineTextAlignment(.center)
            .padding(.top, 2)
        }
        .disabled(busy)
        .sheet(isPresented: $showEmail) {
            EmailAuthSheet { showEmail = false; onSignedIn() }
        }
        .sheet(item: $showLegal) { which in
            NavigationStack {
                LegalDocumentPage(title: which == .terms ? "Terms & Conditions" : "Privacy Policy",
                                  updated: "15 Nov 2026",
                                  sections: which == .terms ? LegalText.terms : LegalText.privacy)
            }
        }
    }

    private func run(_ work: @escaping () async throws -> Void) {
        error = nil
        busy = true
        Task {
            do {
                try await work()
                busy = false
                onSignedIn()
            } catch AuthStore.AuthError.cancelled {
                busy = false
            } catch {
                busy = false
                self.error = error.localizedDescription
            }
        }
    }
}

/// Email + password: sign in, create an account, or reset a forgotten password.
struct EmailAuthSheet: View {
    var onSignedIn: () -> Void

    enum Mode { case signIn, signUp }
    @StateObject private var auth = AuthStore.shared
    @State private var mode: Mode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var message: String?
    @State private var isError = false
    @State private var busy = false
    @FocusState private var focus: Field?
    enum Field { case email, password }

    private var emailOK: Bool { email.contains("@") && email.contains(".") }
    private var canSubmit: Bool { emailOK && password.count >= (mode == .signUp ? 8 : 1) && !busy }

    var body: some View {
        PEPage(title: mode == .signIn ? "Sign in" : "Create account",
               subtitle: mode == .signIn ? "Welcome back." : "Use an email you check. We'll only use it for your account.") {
            HStack(spacing: 6) {
                modeChip("Sign in", .signIn)
                modeChip("Create account", .signUp)
            }

            PESection(title: "Email") {
                TextField("you@example.com", text: $email)
                    .textContentType(.username)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.next)
                    .focused($focus, equals: .email)
                    .onSubmit { focus = .password }
                    .textFieldStyle(PEFieldStyle())
            }
            PESection(title: "Password") {
                SecureField(mode == .signUp ? "At least 8 characters" : "Your password", text: $password)
                    .textContentType(mode == .signUp ? .newPassword : .password)
                    .submitLabel(.go)
                    .focused($focus, equals: .password)
                    .onSubmit { if canSubmit { submit() } }
                    .textFieldStyle(PEFieldStyle())
            }

            Button(mode == .signIn ? "Sign in" : "Create account") { submit() }
                .buttonStyle(PEPrimaryButtonStyle())
                .disabled(!canSubmit)

            if mode == .signIn {
                Button("Forgot password?") { resetPassword() }
                    .font(PETheme.semibold(13.5)).foregroundStyle(PETheme.mar2)
                    .frame(maxWidth: .infinity)
                    .disabled(!emailOK || busy)
            }
            if busy { ProgressView().tint(PETheme.mar).frame(maxWidth: .infinity) }
            if let message {
                PENote(icon: isError ? "exclamationmark.triangle.fill" : "envelope.badge.fill", text: message)
            }
        }
        .onAppear { focus = .email }
    }

    private func modeChip(_ title: String, _ m: Mode) -> some View {
        Text(title)
            .font(PETheme.semibold(13.5))
            .foregroundStyle(mode == m ? PETheme.onMar : PETheme.textSecondary)
            .frame(maxWidth: .infinity).padding(.vertical, 10)
            .peSurface(mode == m ? PETheme.mar : PETheme.card2, radius: PETheme.radiusPill, seed: title.count,
                       stroke: mode == m ? PETheme.textPrimary : PETheme.line2)
            .peChipTraits(selected: mode == m)
            .onTapGesture { withAnimation(.snappy) { mode = m; message = nil } }
    }

    private func submit() {
        let address = email.trimmingCharacters(in: .whitespaces).lowercased()
        message = nil
        busy = true
        Task {
            do {
                if mode == .signIn {
                    try await auth.signIn(email: address, password: password)
                    busy = false
                    onSignedIn()
                } else {
                    switch try await auth.signUp(email: address, password: password) {
                    case .signedIn:
                        busy = false
                        onSignedIn()
                    case .checkEmail:
                        busy = false
                        isError = false
                        message = "Almost there. We sent a confirmation link to \(address). Open it, then come back and sign in."
                        mode = .signIn
                    }
                }
            } catch {
                busy = false
                isError = true
                message = error.localizedDescription
            }
        }
    }

    private func resetPassword() {
        let address = email.trimmingCharacters(in: .whitespaces).lowercased()
        busy = true
        Task {
            do {
                try await auth.sendPasswordReset(email: address)
                isError = false
                message = "If there's an account for \(address), a reset link is on its way."
            } catch {
                isError = true
                message = error.localizedDescription
            }
            busy = false
        }
    }
}
