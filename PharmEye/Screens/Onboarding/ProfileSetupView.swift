import SwiftUI

/// 04 — Profile setup. Onboarding-trust fix: only name/age/gender here ("Just the
/// basics") — allergies/conditions are asked for later via HealthProfilePrompt,
/// right after the first scan, once there's a real reason to ask.
struct ProfileSetupView: View {
    var onContinue: () -> Void
    @AppStorage("profile.name") private var name = ""
    @AppStorage("profile.age") private var age = ""
    @AppStorage("profile.gender") private var gender = ""
    @State private var consented = true

    private let genders = ["Male", "Female", "Prefer not to say"]

    var body: some View {
        ZStack {
            PEPaperBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        PEHeaderIconButton(systemImage: "chevron.left")
                        Spacer()
                        Text("STEP 2 OF 2").font(PETheme.bold(11)).foregroundStyle(PETheme.textTertiary)
                    }
                    Capsule().fill(PETheme.mar).frame(height: 4)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Just the basics").font(PETheme.display(29)).accessibilityAddTraits(.isHeader).foregroundStyle(PETheme.textPrimary)
                        Text("This is enough to get started. We'll ask about allergies and conditions after your first scan, once you can see what they're used for.")
                            .font(PETheme.body(14)).foregroundStyle(PETheme.textSecondary).lineSpacing(2)
                    }

                    field("Full name") { TextField("Your name", text: $name).textFieldStyle(PEFieldStyle()) }
                    field("Age") { TextField("Optional", text: $age).keyboardType(.numberPad).textFieldStyle(PEFieldStyle()) }
                    field("Gender") {
                        HStack(spacing: 8) {
                            ForEach(genders, id: \.self) { g in
                                Text(g)
                                    .font(PETheme.semibold(13.5))
                                    .foregroundStyle(gender == g ? PETheme.onMar : PETheme.textSecondary)
                                    .padding(.horizontal, 16).padding(.vertical, 11)
                                    .peSurface(gender == g ? PETheme.mar : PETheme.card, radius: PETheme.radiusPill, stroke: gender == g ? PETheme.mar : PETheme.line)
                                    .peChipTraits(selected: gender == g)
                                    .onTapGesture { gender = g }
                            }
                        }
                    }

                    infoNote(icon: "pill.fill", title: "Scan your first medicine to unlock warnings",
                             text: "Once you've scanned something, we'll ask about allergies and conditions right there — it'll be obvious why we're asking.")
                    infoNote(icon: "lock.fill", title: nil,
                             text: "Stored encrypted on this device. Nothing leaves your phone unless you turn on sync.")

                    Button {
                        consented.toggle()
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            RoundedRectangle(cornerRadius: 7).fill(consented ? PETheme.mar : PETheme.card2)
                                .overlay(RoundedRectangle(cornerRadius: 7).stroke(PETheme.textPrimary, lineWidth: 1.3))
                                .frame(width: 22, height: 22)
                                .overlay { if consented { Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(PETheme.onMar) } }
                            Text("I understand PharmEye is for information only and does not replace advice from a doctor or pharmacist.")
                                .font(PETheme.body(12.5)).foregroundStyle(PETheme.textSecondary)
                        }
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 16).stroke(consented ? PETheme.mar : PETheme.line))
                    }
                    .buttonStyle(.plain)

                    Button("Continue") { onContinue() }
                        .buttonStyle(PEPrimaryButtonStyle()).padding(.top, 6)
                    Button("Skip for now") { onContinue() }
                        .buttonStyle(PESecondaryButtonStyle())
                }
                .padding(.horizontal, 22).padding(.top, 4).padding(.bottom, 40)
            }
        }
    }

    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(PETheme.bold(12)).foregroundStyle(PETheme.textSecondary)
            content()
        }
    }

    private func infoNote(icon: String, title: String?, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).foregroundStyle(PETheme.mar2).padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                if let title { Text(title).font(PETheme.semibold(12.5)).foregroundStyle(PETheme.textPrimary) }
                Text(text).font(PETheme.body(12.5)).foregroundStyle(PETheme.textSecondary).lineSpacing(2)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .peSurface(PETheme.card, radius: 16, seed: text.count)
    }
}

struct PEFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(PETheme.body(15)).foregroundStyle(PETheme.textPrimary)
            .padding(15)
            .peSurface(PETheme.card, radius: PETheme.radiusField)
    }
}
