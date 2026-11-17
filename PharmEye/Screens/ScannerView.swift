import SwiftUI

/// 08 / 08a — Scanner + the "couldn't read that barcode" failure/offline state.
/// AVFoundation barcode capture itself isn't wired here (needs a real camera session,
/// which the simulator can't exercise anyway) — this is the UI shell + the two outcomes
/// (found → HealthProfilePrompt/Detail, not found → ScanNotFoundView) so the flow is
/// complete and ready for the camera session to slot in.
struct ScannerView: View {
    var onFound: (Medicine) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showNotFound = false

    var body: some View {
        ZStack {
            PETheme.bg.ignoresSafeArea()

            VStack {
                HStack {
                    Button { dismiss() } label: { PEHeaderIconButton(systemImage: "chevron.left") }
                    Spacer()
                    PEHeaderIconButton(systemImage: "clock")
                    PEHeaderIconButton(systemImage: "slider.horizontal.3", square: true)
                }
                .padding(.horizontal, 22).padding(.top, 8)
                Spacer()
            }

            VStack {
                Spacer()
                // Viewfinder sits in the same column as the copy, so the two can never overlap.
                RoundedRectangle(cornerRadius: 16).stroke(PETheme.mar2, lineWidth: 3)
                    .frame(width: 236, height: 236)
                    .opacity(0.9)
                    .padding(.bottom, 32)
                VStack(spacing: 8) {
                    Text("Line up the barcode").font(PETheme.bold(19)).foregroundStyle(PETheme.textPrimary)
                    Text("Hold the box steady. PharmEye reads EAN-13 and Data Matrix codes.")
                        .font(PETheme.body(13)).foregroundStyle(PETheme.textSecondary)
                        .multilineTextAlignment(.center).padding(.horizontal, 40)
                }
                Spacer().frame(height: 70)
                Button {
                    // Demo: "capture" always finds Augmentin, matching the prototype's fixed demo data.
                    onFound(Medicine.sampleCabinet[0])
                    dismiss()
                } label: {
                    Circle().fill(PETheme.textPrimary).frame(width: 68, height: 68)
                        .overlay(Circle().stroke(PETheme.line2, lineWidth: 5).padding(-5))
                }
                .padding(.bottom, 32)
                Button("Couldn't scan? See what that looks like") { showNotFound = true }
                    .font(PETheme.semibold(12.5)).foregroundStyle(PETheme.textSecondary)
                    .padding(.bottom, 20)
            }
        }
        // A camera viewfinder reads best dark, so the capture screen always uses the night tokens.
        .environment(\.colorScheme, .dark)
        .sheet(isPresented: $showNotFound) { ScanNotFoundView() }
    }
}

/// 08a — failure / offline state.
struct ScanNotFoundView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ZStack {
            PEPaperBackground()
            VStack {
                HStack { Button { dismiss() } label: { PEHeaderIconButton(systemImage: "chevron.left") }; Spacer() }
                    .padding(.horizontal, 22).padding(.top, 14)

                Spacer()
                VStack(spacing: 20) {
                    Circle().fill(PETheme.roseDim).frame(width: 84, height: 84)
                        .overlay(Image(systemName: "barcode.viewfinder").font(.system(size: 30)).foregroundStyle(PETheme.rose))
                    VStack(spacing: 10) {
                        Text("Couldn't read that barcode").font(PETheme.bold(21)).foregroundStyle(PETheme.textPrimary)
                        Text("This one isn't in our UAE medicine catalog yet, or the code didn't scan cleanly. Try a clearer photo, or add it yourself.")
                            .font(PETheme.body(13.5)).foregroundStyle(PETheme.textSecondary)
                            .multilineTextAlignment(.center).padding(.horizontal, 32)
                    }
                    VStack(spacing: 10) {
                        Button { dismiss() } label: {
                            HStack { Image(systemName: "barcode.viewfinder"); Text("Try again") }
                        }.buttonStyle(PEPrimaryButtonStyle())
                        Button("Photograph the box instead") { dismiss() }.buttonStyle(PESecondaryButtonStyle())
                        Button("Type the name manually") { dismiss() }
                            .font(PETheme.semibold(14)).foregroundStyle(PETheme.textSecondary)
                    }
                    .padding(.horizontal, 22)
                }
                Spacer()

                HStack(alignment: .top, spacing: 11) {
                    Image(systemName: "wifi.slash").foregroundStyle(PETheme.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("You're offline").font(PETheme.bold(12)).foregroundStyle(PETheme.orange)
                        Text("New medicines need a connection the first time. Your existing cabinet still works fully offline.")
                            .font(PETheme.body(12)).foregroundStyle(PETheme.textSecondary).lineSpacing(2)
                    }
                }
                .padding(14)
                .peSurface(PETheme.orangeDim, radius: 16, stroke: PETheme.orange.opacity(0.25))
                .padding(.horizontal, 22).padding(.bottom, 30)
            }
        }
    }
}
