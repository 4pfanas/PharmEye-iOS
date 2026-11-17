import SwiftUI

/// 08b — Health profile prompt. The onboarding-trust payoff: shown as a sheet right
/// after the first scan finds a real conflict, using that conflict as the reason to
/// ask for allergies/conditions instead of asking blind at signup.
struct HealthProfilePromptView: View {
    var medicineName: String = "Augmentin"
    var onSave: (Set<String>, String) -> Void
    var onDismiss: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var allergies: Set<String> = []
    @State private var conditions = ""

    private let allergyOptions = ["Penicillin", "Sulfa drugs", "Aspirin", "Ibuprofen", "Latex"]

    var body: some View {
        ZStack {
            PEPaperBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Button { onDismiss(); dismiss() } label: { PEHeaderIconButton(systemImage: "chevron.left") }
                        Spacer()
                    }

                    VStack(spacing: 12) {
                        Circle().fill(PETheme.mar.opacity(0.18)).frame(width: 60, height: 60)
                            .overlay(Image(systemName: "pill.fill").foregroundStyle(PETheme.mar2))
                        Text("You just scanned your first medicine.")
                            .font(PETheme.display(24)).foregroundStyle(PETheme.textPrimary).multilineTextAlignment(.center)
                        Text("A couple of quick questions now could catch conflicts like this one before they matter.")
                            .font(PETheme.body(14)).foregroundStyle(PETheme.textSecondary).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)

                    HStack(alignment: .top, spacing: 11) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(PETheme.rose)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(medicineName) contains a penicillin").font(PETheme.bold(12.5)).foregroundStyle(PETheme.rose)
                            Text("If you're allergic to penicillin, this is exactly the kind of conflict we'd flag automatically — but only once we know.")
                                .font(PETheme.body(12.5)).foregroundStyle(PETheme.textSecondary).lineSpacing(2)
                        }
                    }
                    .padding(15)
                    .peSurface(PETheme.roseDim, radius: 18, stroke: PETheme.rose.opacity(0.3))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Any known allergies? · optional").font(PETheme.bold(12)).foregroundStyle(PETheme.textSecondary)
                        FlowChips(options: allergyOptions, selected: $allergies)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ongoing conditions · optional").font(PETheme.bold(12)).foregroundStyle(PETheme.textSecondary)
                        TextField("e.g. asthma, type 2 diabetes", text: $conditions, axis: .vertical)
                            .lineLimit(3...5)
                            .font(PETheme.body(15)).foregroundStyle(PETheme.textPrimary)
                            .padding(15)
                            .peSurface(PETheme.card, radius: PETheme.radiusField)
                    }

                    Button("Save and check for conflicts") { onSave(allergies, conditions); dismiss() }
                        .buttonStyle(PEPrimaryButtonStyle()).padding(.top, 6)
                    Button("Not now — ask me later") { onDismiss(); dismiss() }
                        .font(PETheme.semibold(15)).foregroundStyle(PETheme.textSecondary)
                        .frame(maxWidth: .infinity).frame(height: 48)
                }
                .padding(.horizontal, 22).padding(.bottom, 30)
            }
        }
    }
}

/// Wrapping chip picker, used here and could be reused by ProfileSetup's allergy step
/// in a future revision if that ever needs multi-select again.
struct FlowChips: View {
    let options: [String]
    @Binding var selected: Set<String>

    var body: some View {
        // Simple wrap using a LazyVGrid-free flow via HStack wrapping in a ScrollView
        // keeps this dependency-free; fine at this option count.
        FlexibleView(data: options, spacing: 8, alignment: .leading) { option in
            chip(option)
        }
    }

    private func chip(_ option: String) -> some View {
        let isOn = selected.contains(option)
        return HStack(spacing: 6) {
            if isOn { Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)) }
            Text(option)
        }
        .font(PETheme.semibold(13))
        .foregroundStyle(isOn ? PETheme.onMar : PETheme.textSecondary)
        .padding(.horizontal, 16).padding(.vertical, 11)
        .peSurface(isOn ? PETheme.mar : PETheme.card, radius: PETheme.radiusPill, seed: option.count,
                   stroke: isOn ? PETheme.textPrimary : PETheme.line2)
        .peChipTraits(selected: isOn)
        .onTapGesture {
            if isOn { selected.remove(option) } else { selected.insert(option) }
        }
    }
}

/// Minimal flow-layout helper (no external dependency) for wrapping chip rows.
struct FlexibleView<Data: Collection, Content: View>: View where Data.Element: Hashable {
    let data: Data
    let spacing: CGFloat
    let alignment: HorizontalAlignment
    let content: (Data.Element) -> Content

    @State private var totalHeight = CGFloat.zero

    var body: some View {
        VStack {
            GeometryReader { geometry in
                self.generateContent(in: geometry)
            }
        }
        .frame(height: totalHeight)
    }

    private func generateContent(in g: GeometryProxy) -> some View {
        var width = CGFloat.zero
        var height = CGFloat.zero
        return ZStack(alignment: .topLeading) {
            ForEach(Array(data), id: \.self) { item in
                content(item)
                    .padding(.trailing, spacing).padding(.bottom, spacing)
                    .alignmentGuide(.leading) { d in
                        if abs(width - d.width) > g.size.width {
                            width = 0; height -= d.height + spacing
                        }
                        let result = width
                        if item == Array(data).last { width = 0 } else { width -= d.width + spacing }
                        return result
                    }
                    .alignmentGuide(.top) { _ in
                        let result = height
                        if item == Array(data).last { height = 0 }
                        return result
                    }
            }
        }
        .background(GeometryReader { geo -> Color in
            DispatchQueue.main.async { self.totalHeight = geo.size.height }
            return Color.clear
        })
    }
}
