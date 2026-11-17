import SwiftUI

/// 09 — Symptom check. Sends what the user describes to their own AI provider
/// (Services/SymptomAI.swift) and shows ranked possible causes with percentage
/// match scores — the format agreed in the design pass. The methodology is stated in
/// the disclaimer below for App Review guideline 1.4.1. Always framed as "not a diagnosis".
struct SymptomsView: View {
    @EnvironmentObject private var cabinet: CabinetStore
    @AppStorage("ai.provider") private var provider = "Gemini"
    @Environment(\.dismiss) private var dismiss
    @State private var showScanner = false
    @State private var text: String
    private let showsBack: Bool
    @State private var selected: Set<String> = []
    @State private var report: SymptomReport?
    @State private var error: String?
    @State private var isChecking = false
    private let chips = ["Sore throat", "Fever", "Headache", "Cough", "Fatigue", "Nausea", "Dizziness", "Rash", "Stomach pain"]

    /// `showsBack` is for when this is pushed (e.g. from Search) rather than shown as a tab.
    init(initialText: String = "", showsBack: Bool = false) {
        _text = State(initialValue: initialText)
        self.showsBack = showsBack
    }

    private var hasKey: Bool { Keychain.get(account: Keychain.aiKeyAccount) != nil }
    private var description: String {
        let typed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let picked = selected.sorted().joined(separator: ", ")
        return [typed, picked.isEmpty ? "" : "Symptoms: \(picked)."].filter { !$0.isEmpty }.joined(separator: "\n")
    }

    var body: some View {
        ZStack {
            PEPaperBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        if showsBack {
                            Button { dismiss() } label: { PEHeaderIconButton(systemImage: "chevron.left") }
                        }
                        Text("Symptom check").font(PETheme.display(24)).accessibilityAddTraits(.isHeader).foregroundStyle(PETheme.textPrimary)
                            .lineLimit(1).minimumScaleFactor(0.75)
                        Spacer()
                        Button { showScanner = true } label: { PEHeaderIconButton(systemImage: "barcode.viewfinder", square: true) }
                        NavigationLink { NotificationsView() } label: { PEHeaderIconButton(systemImage: "bell.fill", badge: true) }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        TextField("Describe how you feel — e.g. sore throat for 3 days, mild fever", text: $text, axis: .vertical)
                            .lineLimit(2...5)
                            .font(PETheme.body(14.5)).foregroundStyle(PETheme.textPrimary)
                        Divider().overlay(PETheme.line)
                        HStack {
                            Text(hasKey ? "Checked by \(provider) · \(selected.count) selected" : "Needs your AI key")
                                .font(PETheme.semibold(11.5)).foregroundStyle(PETheme.textTertiary)
                            Spacer()
                            Button(action: runCheck) {
                                Circle().fill(PETheme.mar).frame(width: 42, height: 42)
                                    .overlay {
                                        if isChecking {
                                            ProgressView().tint(PETheme.onMar)
                                        } else {
                                            Image(systemName: "paperplane.fill").font(.system(size: 15)).foregroundStyle(PETheme.onMar)
                                        }
                                    }
                            }
                            .disabled(isChecking || description.isEmpty)
                            .opacity(description.isEmpty ? 0.45 : 1)
                            .accessibilityLabel("Run symptom check")
                        }
                    }
                    .padding(16)
                    .peSurface(PETheme.card, radius: 22)

                    FlexibleView(data: chips, spacing: 8, alignment: .leading) { chip in
                        chipView(chip)
                    }

                    if !hasKey {
                        NavigationLink { AIProviderPage() } label: {
                            PENote(icon: "key.fill", text: "Add your Gemini, Claude or OpenAI key in Profile → AI provider key to run a check. Tap here to add it now.")
                        }
                        .buttonStyle(.plain)
                    }

                    if let error {
                        PENote(icon: "exclamationmark.triangle.fill", text: error)
                    }

                    if let report {
                        results(report)
                    }

                    HStack(alignment: .top, spacing: 11) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(PETheme.orange)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Not a diagnosis").font(PETheme.bold(12.5)).foregroundStyle(PETheme.orange)
                            Text("These are AI-generated suggestions based only on what you typed. The percentage is how closely each one matches your description, not a medical probability. Seek urgent care for trouble breathing, chest pain or a fever above 39°C.")
                                .font(PETheme.body(12.5)).foregroundStyle(PETheme.textSecondary).lineSpacing(2)
                        }
                    }
                    .padding(15)
                    .peSurface(PETheme.orangeDim, radius: 18, stroke: PETheme.orange.opacity(0.4))
                }
                .padding(.horizontal, 22).padding(.top, 8).padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .toolbar(.hidden)
        .sheet(isPresented: $showScanner) {
            ScannerView { cabinet.addScannedMedicine($0) }
        }
    }

    private func chipView(_ chip: String) -> some View {
        let isOn = selected.contains(chip)
        return HStack(spacing: 6) {
            if isOn { Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)) }
            Text(chip)
        }
        .font(PETheme.semibold(13))
        .foregroundStyle(isOn ? PETheme.onMar : PETheme.textSecondary)
        .padding(.horizontal, 16).padding(.vertical, 11)
        .peSurface(isOn ? PETheme.mar : PETheme.card, radius: PETheme.radiusPill, seed: chip.count,
                   stroke: isOn ? PETheme.textPrimary : PETheme.line2)
        .peChipTraits(selected: isOn)
        .onTapGesture {
            if isOn { selected.remove(chip) } else { selected.insert(chip) }
        }
    }

    @ViewBuilder private func results(_ report: SymptomReport) -> some View {
        if report.urgent {
            HStack(alignment: .top, spacing: 11) {
                Image(systemName: "cross.case.fill").foregroundStyle(PETheme.rose)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Get help now").font(PETheme.bold(13.5)).foregroundStyle(PETheme.rose)
                    Text(report.urgentAdvice.isEmpty ? "Call 998 or go to the nearest emergency department." : report.urgentAdvice)
                        .font(PETheme.body(13)).foregroundStyle(PETheme.textPrimary).lineSpacing(2)
                }
            }
            .padding(15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .peSurface(PETheme.roseDim, radius: 18, stroke: PETheme.rose)
        }
        HStack {
            Text("POSSIBLE CAUSES").font(PETheme.bold(11)).foregroundStyle(PETheme.textTertiary)
            Spacer()
            Text("\(report.causes.count) matches").font(PETheme.semibold(11.5)).foregroundStyle(PETheme.textTertiary)
        }
        VStack(spacing: 10) {
            ForEach(report.causes, id: \.self) { resultCard($0) }
        }
    }

    private func style(for label: String) -> (PEBadge.Tone, Color) {
        switch label {
        case "Most likely": (.green, PETheme.green)
        case "Needs a test": (.orange, PETheme.orange)
        case "See a doctor": (.rose, PETheme.rose)
        case "Possible": (.gold, PETheme.gold)
        default: (.mute, PETheme.textTertiary)
        }
    }

    private func resultCard(_ c: SymptomCause) -> some View {
        let (tone, color) = style(for: c.label)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(c.name).font(PETheme.bold(15)).foregroundStyle(PETheme.textPrimary)
                Spacer()
                PEBadge(text: c.label, tone: tone)
            }
            HStack(spacing: 9) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(PETheme.card3)
                        Capsule().fill(color).frame(width: geo.size.width * Double(c.matchPercent) / 100)
                    }
                }
                .frame(height: 6)
                Text("\(c.matchPercent)%").font(PETheme.bold(11)).foregroundStyle(PETheme.textSecondary)
            }
            Text(c.explanation).font(PETheme.body(13)).foregroundStyle(PETheme.textSecondary).lineSpacing(2)
        }
        .padding(16)
        .peSurface(PETheme.card, radius: 20, seed: c.name.count)
        .accessibilityElement(children: .combine)
    }

    private func runCheck() {
        let query = description
        // No key: the "add your key" card above already says what to do.
        guard !query.isEmpty, hasKey else { return }
        isChecking = true
        error = nil
        Task {
            do {
                let result = try await SymptomAI.check(symptoms: query, provider: provider)
                withAnimation(.snappy) { report = result }
            } catch {
                self.error = error.localizedDescription
            }
            isChecking = false
        }
    }
}
