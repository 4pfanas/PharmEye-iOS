import SwiftUI

/// 01 — Splash. Shown for ~1.4s then auto-advances to Get Started.
struct SplashView: View {
    var onFinished: () -> Void
    @State private var scale: CGFloat = 0.84
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            PEPaperBackground()
            VStack(spacing: 17) {
                LogoMark()
                    .frame(width: 88, height: 88)
                    .scaleEffect(scale)
                    .opacity(opacity)
                Text("PharmEye").font(PETheme.display(27)).accessibilityAddTraits(.isHeader).foregroundStyle(PETheme.textPrimary)
                Text("Know your medicine").font(PETheme.body(12.5)).foregroundStyle(PETheme.textTertiary)
            }
            VStack {
                Spacer()
                Text("LOADING YOUR CABINET")
                    .font(PETheme.bold(11)).foregroundStyle(PETheme.textTertiary)
                    .padding(.bottom, 58)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.85, dampingFraction: 0.8)) { scale = 1; opacity = 1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { onFinished() }
        }
    }
}

/// The eye/pill logomark, redrawn from the prototype's inline SVG paths as a SwiftUI Shape.
struct LogoMark: View {
    var body: some View {
        ZStack {
            EyeOutline().stroke(PETheme.mar, lineWidth: 5)
            Circle().fill(PETheme.mar).frame(width: 36, height: 36)
            Image(systemName: "pill.fill")
                .resizable().scaledToFit().frame(width: 16, height: 16)
                .foregroundStyle(PETheme.gold2)
                .rotationEffect(.degrees(-45))
        }
    }
}
struct EyeOutline: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        p.move(to: CGPoint(x: 0.04*w, y: 0.5*h))
        p.addCurve(to: CGPoint(x: 0.5*w, y: 0.204*h),
                    control1: CGPoint(x: 0.155*w, y: 0.302*h), control2: CGPoint(x: 0.317*w, y: 0.204*h))
        p.addCurve(to: CGPoint(x: 0.958*w, y: 0.5*h),
                    control1: CGPoint(x: 0.683*w, y: 0.204*h), control2: CGPoint(x: 0.845*w, y: 0.302*h))
        p.addCurve(to: CGPoint(x: 0.5*w, y: 0.796*h),
                    control1: CGPoint(x: 0.845*w, y: 0.698*h), control2: CGPoint(x: 0.683*w, y: 0.796*h))
        p.addCurve(to: CGPoint(x: 0.04*w, y: 0.5*h),
                    control1: CGPoint(x: 0.317*w, y: 0.796*h), control2: CGPoint(x: 0.155*w, y: 0.698*h))
        p.closeSubpath()
        return p
    }
}
