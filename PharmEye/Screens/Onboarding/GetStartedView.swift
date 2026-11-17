import SwiftUI

/// 02 — Get Started.
struct GetStartedView: View {
    var onContinue: () -> Void
    var body: some View {
        ZStack {
            PEPaperBackground()
            VStack(spacing: 0) {
                heroArt.padding(.horizontal, 22).padding(.top, 6)

                VStack(spacing: 12) {
                    Text("Every medicine,\nexplained plainly")
                        .font(PETheme.display(31)).foregroundStyle(PETheme.textPrimary)
                        .multilineTextAlignment(.center)
                    Text("Scan the box or type the name. PharmEye tells you what it treats, how much to take and what to watch for.")
                        .font(PETheme.body(14.5)).foregroundStyle(PETheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 26).padding(.horizontal, 28)

                Spacer()

                HStack(spacing: 6) {
                    Capsule().fill(PETheme.mar).frame(width: 22, height: 6)
                    Circle().fill(PETheme.line2).frame(width: 6, height: 6)
                    Circle().fill(PETheme.line2).frame(width: 6, height: 6)
                }
                .padding(.bottom, 20)

                Button { onContinue() } label: {
                    HStack { Text("Get Started"); Image(systemName: "arrow.up.right") }
                }
                .buttonStyle(PEPrimaryButtonStyle())
                .padding(.horizontal, 22).padding(.bottom, 34)
            }
        }
    }

    private var heroArt: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(.clear)
                .peSurface(PETheme.card, radius: 32, seed: 23)
            Image(systemName: "pill.fill")
                .resizable().scaledToFit().frame(width: 110, height: 110)
                .rotationEffect(.degrees(-38))
                .foregroundStyle(PETheme.mar)
            VStack {
                HStack { floatChip("barcode.viewfinder", "Scan a box"); Spacer() }
                Spacer()
                HStack { Spacer(); floatChip("clock", "Dose reminders") }
                Spacer()
                HStack { floatChip("waveform.path.ecg", "Symptom check"); Spacer() }
            }
            .padding(18)
        }
        .frame(height: 322)
    }

    private func floatChip(_ icon: String, _ text: String) -> some View {
        Label(text, systemImage: icon)
            .font(PETheme.semibold(12))
            .foregroundStyle(PETheme.textPrimary)
            .padding(.horizontal, 13).padding(.vertical, 9)
            .peSurface(PETheme.card2, radius: PETheme.radiusPill, seed: text.count)
    }
}
