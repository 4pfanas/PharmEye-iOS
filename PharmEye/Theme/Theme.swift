import SwiftUI
import CoreText

/// Raw palette, adapted from the "Eleanor Khatoon" paper system (maroon / cream / gold).
/// Screens never read these directly — they go through the semantic `PETheme` tokens
/// below, which pick the right value for light ("paper") and dark ("night") mode.
enum PEPalette {
    static let paper  = Color(hex: 0xEFE3CB)
    static let sand   = Color(hex: 0xE4D1A8)
    static let cream  = Color(hex: 0xFBF4E4)
    static let ink    = Color(hex: 0x3A0F1A)
    static let mar    = Color(hex: 0x6A1B2D)
    static let mar2   = Color(hex: 0x8A2B3A)
    static let rose   = Color(hex: 0xB4473F)
    static let gold   = Color(hex: 0xC8982F)
    static let gold2  = Color(hex: 0xE6C16A)
    static let night  = Color(hex: 0x2A1220)
    static let deep   = Color(hex: 0x4B1222)
    static let green  = Color(hex: 0x7C8F5A)
    static let orange = Color(hex: 0xE88A3C)
    static let ice    = Color(hex: 0xD6E7EC) // reserved — hydration, if ever added
    static let ice2   = Color(hex: 0x9CC3D1)
}

/// PharmEye's semantic design tokens. Every text/icon pairing below clears WCAG AA
/// (4.5:1) on both `bg` and `card` in both modes — the raw green/orange/gold palette
/// values do not (2.0–2.8:1 on paper), so they are only used as fills via the
/// `*Fill` tokens, and darker "ink" variants carry status text.
enum PETheme {

    // MARK: Surfaces
    static let bg    = Color(light: 0xEFE3CB, dark: 0x2A1220) // paper / night
    static let card  = Color(light: 0xE4D1A8, dark: 0x4B1222) // sand / deep
    static let card2 = Color(light: 0xFBF4E4, dark: 0x5C1A2C) // cream — raised / active
    static let card3 = Color(light: 0xEFE3CB, dark: 0x2A1220) // inset chip sitting on a card
    static let line  = Color(light: 0x3A0F1A, dark: 0xFBF4E4, lightAlpha: 0.22, darkAlpha: 0.16)
    static let line2 = Color(light: 0x3A0F1A, dark: 0xFBF4E4, lightAlpha: 0.55, darkAlpha: 0.32)

    // MARK: Text
    static let textPrimary   = Color(light: 0x3A0F1A, dark: 0xFBF4E4) // ink / cream
    static let textSecondary = Color(light: 0x8A2B3A, dark: 0xE4D1A8) // mar2 / sand
    static let textTertiary  = Color(light: 0x9A3933, dark: 0xC9A0A8) // rose, darkened to pass AA

    // MARK: Brand
    /// Primary fill — buttons, active tab, key icons. Gold in night mode, where maroon
    /// on night would only reach 1.5:1.
    static let mar    = Color(light: 0x6A1B2D, dark: 0xC8982F)
    /// Headline emphasis, links, section icons.
    static let mar2   = Color(light: 0x8A2B3A, dark: 0xE6C16A)
    /// Text / icons sitting on a `mar` fill.
    static let onMar  = Color(light: 0xFBF4E4, dark: 0x2A1220)
    static let gold   = PEPalette.gold
    static let gold2  = PEPalette.gold2

    // MARK: Status
    // Text-safe tones (labels, icons, badge text)…
    static let green  = Color(light: 0x4F5E33, dark: 0xA9C08A) // taken / on track
    static let orange = Color(light: 0x8C4710, dark: 0xF0A660) // due soon / low stock
    static let rose   = Color(light: 0x9A3933, dark: 0xD9897F) // missed / allergy
    // …and the true palette colours, for stripes, dots and tinted backgrounds.
    static let greenFill  = PEPalette.green
    static let orangeFill = PEPalette.orange
    static let roseFill   = PEPalette.rose
    static let greenDim   = PEPalette.green.opacity(0.24)
    static let orangeDim  = PEPalette.orange.opacity(0.24)
    static let roseDim    = PEPalette.rose.opacity(0.20)

    // MARK: Radii
    static let radiusPill: CGFloat = 999
    static let radiusChip: CGFloat = 14
    static let radiusCard: CGFloat = 22
    static let radiusCardLg: CGFloat = 26
    static let radiusField: CGFloat = 16
    static let radiusSquareBtn: CGFloat = 14

    // MARK: Type
    // Poppins (display + all UI/data text) and Lora (narrative copy only — empty states,
    // reassurance lines). A serif slows scanning in dose lists and form fields, so
    // data-heavy text stays sans. Fonts ship in Fonts/ and are registered at launch by
    // `PEFonts.register()`; unregistered, iOS silently falls back to the system font.
    static func display(_ size: CGFloat) -> Font {
        .custom("Poppins-Bold", size: size, relativeTo: .largeTitle)
    }
    static func body(_ size: CGFloat) -> Font {
        .custom("Poppins-Regular", size: size)
    }
    static func semibold(_ size: CGFloat) -> Font {
        .custom("Poppins-SemiBold", size: size)
    }
    static func bold(_ size: CGFloat) -> Font {
        .custom("Poppins-Bold", size: size)
    }
    static func prose(_ size: CGFloat, italic: Bool = false) -> Font {
        let f = Font.custom("Lora", size: size)
        return italic ? f.italic() : f
    }
}

enum PEFonts {
    /// Registers every bundled .ttf for this process. Safe to call more than once.
    static func register() {
        let urls = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? []
        for url in urls {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }

    /// A colour that follows the system appearance: paper in light mode, night in dark.
    init(light: UInt32, dark: UInt32, lightAlpha: CGFloat = 1, darkAlpha: CGFloat = 1) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(hex: dark, alpha: darkAlpha)
                : UIColor(hex: light, alpha: lightAlpha)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

// MARK: - Hand-drawn shapes

/// A rounded rectangle whose outline wobbles slightly, like a pen line on paper.
/// The wobble is deterministic per `seed`, so a card looks the same on every redraw
/// (and two neighbouring cards don't look stamped from one template).
/// Radius is clamped to half the short side, so `radiusPill` gives a hand-drawn capsule.
struct PESketchRect: Shape {
    var cornerRadius: CGFloat = PETheme.radiusCard
    var seed: Int = 0
    var wobble: CGFloat = 0.9

    func path(in rect: CGRect) -> Path {
        let r = min(cornerRadius, rect.width / 2, rect.height / 2)
        let w = rect.width - 2 * r, h = rect.height - 2 * r
        let arc = CGFloat.pi / 2 * r
        let perimeter = 2 * (w + h) + 4 * arc
        guard perimeter > 0 else { return Path() }

        let steps = max(24, Int(perimeter / 5))
        let s = CGFloat(abs(seed) % 997)
        var path = Path()
        for i in 0...steps {
            let d = perimeter * CGFloat(i) / CGFloat(steps)
            let (p, n) = point(at: d, in: rect, r: r, w: w, h: h, arc: arc)
            // Two low-frequency sines read as a hand tremor, not as noise.
            let t = d / perimeter * 2 * .pi
            let off = wobble * (0.65 * sin(t * 3 + s) + 0.35 * sin(t * 7 + s * 1.7))
            let q = CGPoint(x: p.x + n.dx * off, y: p.y + n.dy * off)
            if i == 0 { path.move(to: q) } else { path.addLine(to: q) }
        }
        path.closeSubpath()
        return path
    }

    /// Point and outward normal at distance `d` along the perimeter, clockwise from top-left.
    private func point(at d: CGFloat, in rect: CGRect, r: CGFloat, w: CGFloat, h: CGFloat, arc: CGFloat)
        -> (CGPoint, CGVector) {
        var d = d
        let x0 = rect.minX, y0 = rect.minY
        func corner(_ cx: CGFloat, _ cy: CGFloat, _ start: CGFloat, _ d: CGFloat) -> (CGPoint, CGVector) {
            let a = start + (r > 0 ? d / r : 0)
            return (CGPoint(x: cx + r * cos(a), y: cy + r * sin(a)), CGVector(dx: cos(a), dy: sin(a)))
        }
        if d < w { return (CGPoint(x: x0 + r + d, y: y0), CGVector(dx: 0, dy: -1)) }; d -= w
        if d < arc { return corner(x0 + r + w, y0 + r, -.pi / 2, d) }; d -= arc
        if d < h { return (CGPoint(x: rect.maxX, y: y0 + r + d), CGVector(dx: 1, dy: 0)) }; d -= h
        if d < arc { return corner(x0 + r + w, y0 + r + h, 0, d) }; d -= arc
        if d < w { return (CGPoint(x: rect.maxX - r - d, y: rect.maxY), CGVector(dx: 0, dy: 1)) }; d -= w
        if d < arc { return corner(x0 + r, y0 + r + h, .pi / 2, d) }; d -= arc
        if d < h { return (CGPoint(x: x0, y: rect.maxY - r - d), CGVector(dx: -1, dy: 0)) }; d -= h
        return corner(x0 + r, y0 + r, .pi, min(d, arc))
    }
}

extension View {
    /// Tap-to-toggle chips are plain views with a tap gesture, so tell VoiceOver they are
    /// buttons, and whether this one is currently picked.
    func peChipTraits(selected: Bool) -> some View {
        accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    /// Flat fill + hand-drawn ink outline. Replaces v1's soft glows: no shadows,
    /// no gradients.
    func peSurface(_ fill: Color = PETheme.card, radius: CGFloat = PETheme.radiusCard,
                   seed: Int = 0, stroke: Color = PETheme.line2) -> some View {
        background(fill, in: PESketchRect(cornerRadius: radius, seed: seed))
            .overlay(PESketchRect(cornerRadius: radius, seed: seed).stroke(stroke, lineWidth: 1.3))
    }
}

/// Page background: flat paper (or night) plus a faint, fixed grain.
struct PEPaperBackground: View {
    var body: some View {
        PETheme.bg
            .overlay {
                Canvas { ctx, size in
                    var rng = SeededGenerator(seed: 7)
                    let count = Int(size.width * size.height / 180)
                    for _ in 0..<count {
                        let x = CGFloat.random(in: 0...size.width, using: &rng)
                        let y = CGFloat.random(in: 0...size.height, using: &rng)
                        let d = CGFloat.random(in: 0.6...1.6, using: &rng)
                        let a = Double.random(in: 0.03...0.09, using: &rng)
                        ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: d, height: d)),
                                 with: .color(PETheme.textPrimary.opacity(a)))
                    }
                }
                .allowsHitTesting(false)
            }
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}

/// Tiny deterministic RNG so the paper grain never shimmers between redraws.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = (seed &* 0x9E3779B97F4A7C15) | 1 }
    mutating func next() -> UInt64 {
        state ^= state << 13; state ^= state >> 7; state ^= state << 17
        return state
    }
}

// MARK: - Buttons

/// Fades any PharmEye button while it is disabled, so a Save that can't run yet looks it.
struct PEDimWhenDisabled: ViewModifier {
    @Environment(\.isEnabled) private var isEnabled
    func body(content: Content) -> some View { content.opacity(isEnabled ? 1 : 0.45) }
}

/// Shared button styles. Pill-shaped (radius-pill), flat, ink-outlined.
struct PEPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(PETheme.bold(16))
            .foregroundStyle(PETheme.onMar)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .peSurface(PETheme.mar, radius: PETheme.radiusPill, seed: 3, stroke: PETheme.textPrimary)
            .modifier(PEDimWhenDisabled())
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct PESecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(PETheme.bold(15))
            .foregroundStyle(PETheme.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .peSurface(PETheme.card2, radius: PETheme.radiusPill, seed: 11)
            .modifier(PEDimWhenDisabled())
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct PEAuthButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(PETheme.bold(16))
            .foregroundStyle(PETheme.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .peSurface(PETheme.card2, radius: PETheme.radiusPill, seed: 5, stroke: PETheme.textPrimary)
            .modifier(PEDimWhenDisabled())
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }
}

/// Circular/rounded-square header buttons — scan, bell, filter icons.
struct PEHeaderIconButton: View {
    let systemImage: String
    var square = false
    var badge = false
    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(PETheme.textPrimary)
            .frame(width: 44, height: 44)
            .peSurface(PETheme.card2, radius: square ? PETheme.radiusSquareBtn : 22, seed: systemImage.count)
            .overlay(alignment: .topTrailing) {
                if badge {
                    Circle().fill(PETheme.roseFill).frame(width: 9, height: 9)
                        .overlay(Circle().stroke(PETheme.bg, lineWidth: 2))
                        .offset(x: -8, y: 8)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(spokenName)
    }

    /// What VoiceOver says for each icon — icons alone mean nothing when read aloud.
    private var spokenName: String {
        let name: String
        switch systemImage {
        case "barcode.viewfinder": name = "Scan a medicine"
        case "bell.fill": name = "Notifications"
        case "plus": name = "Add a medicine"
        case "chevron.left": name = "Back"
        case "xmark": name = "Close"
        case "pencil": name = "Edit"
        case "phone.fill": name = "Call"
        case "clock": name = "History"
        case "slider.horizontal.3": name = "Settings"
        default: name = systemImage.replacingOccurrences(of: ".", with: " ")
        }
        return badge ? "\(name), new alerts" : name
    }
}

/// Small pill badge. `.gold` is the highlight chip (e.g. the next-dose countdown).
struct PEBadge: View {
    enum Tone { case green, orange, rose, gold, mute }
    let text: String
    var tone: Tone = .green

    private var fg: Color {
        switch tone {
        case .green:  PETheme.green
        case .orange: PETheme.orange
        case .rose:   PETheme.rose
        case .gold:   PEPalette.ink
        case .mute:   PETheme.textTertiary
        }
    }
    private var bg: Color {
        switch tone {
        case .green:  PETheme.greenDim
        case .orange: PETheme.orangeDim
        case .rose:   PETheme.roseDim
        case .gold:   PETheme.gold2
        case .mute:   PETheme.line
        }
    }

    var body: some View {
        Text(text)
            .font(PETheme.bold(11))
            .foregroundStyle(fg)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(bg, in: RoundedRectangle(cornerRadius: tone == .gold ? PETheme.radiusChip : PETheme.radiusPill, style: .continuous))
    }
}
