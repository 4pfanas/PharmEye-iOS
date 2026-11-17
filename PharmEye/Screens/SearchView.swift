import SwiftUI

/// Search from Home: matches medicines in the cabinet (name, ingredients, category,
/// what it treats) and offers to run a symptom check on whatever was typed.
struct SearchView: View {
    @EnvironmentObject private var cabinet: CabinetStore
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @FocusState private var focused: Bool

    private var trimmed: String { query.trimmingCharacters(in: .whitespaces) }

    private var matches: [Medicine] {
        guard !trimmed.isEmpty else { return cabinet.medicines }
        return cabinet.medicines.filter { med in
            [med.name, med.strength, med.composition, med.category, med.whatItTreats]
                .contains { $0.localizedCaseInsensitiveContains(trimmed) }
        }
    }

    var body: some View {
        ZStack {
            PEPaperBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 10) {
                        Button { dismiss() } label: { PEHeaderIconButton(systemImage: "chevron.left") }
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass").foregroundStyle(PETheme.textTertiary)
                            TextField("Search a medicine or symptom", text: $query)
                                .font(PETheme.body(15)).foregroundStyle(PETheme.textPrimary)
                                .focused($focused)
                                .submitLabel(.search)
                                .autocorrectionDisabled()
                            if !query.isEmpty {
                                Button { query = "" } label: {
                                    Image(systemName: "xmark.circle.fill").foregroundStyle(PETheme.textTertiary)
                                }
                            }
                        }
                        .padding(.horizontal, 16).frame(height: 48)
                        .peSurface(PETheme.card, radius: PETheme.radiusPill)
                    }

                    if !trimmed.isEmpty {
                        NavigationLink { SymptomsView(initialText: trimmed, showsBack: true) } label: {
                            HStack(spacing: 13) {
                                Image(systemName: "waveform.path.ecg").foregroundStyle(PETheme.onMar)
                                    .frame(width: 40, height: 40).background(PETheme.mar, in: RoundedRectangle(cornerRadius: 13))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Check symptoms").font(PETheme.semibold(14.5)).foregroundStyle(PETheme.textPrimary)
                                    Text("“\(trimmed)”").font(PETheme.body(12)).foregroundStyle(PETheme.textTertiary).lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(PETheme.textTertiary)
                            }
                            .padding(14)
                            .peSurface(PETheme.card2, radius: 20, seed: 6)
                        }
                        .buttonStyle(.plain)
                    }

                    Text(trimmed.isEmpty ? "IN YOUR CABINET" : "MEDICINES · \(matches.count)")
                        .font(PETheme.bold(11)).foregroundStyle(PETheme.textTertiary)

                    if matches.isEmpty {
                        Text("Nothing in your cabinet matches “\(trimmed)”.")
                            .font(PETheme.prose(14.5)).foregroundStyle(PETheme.textSecondary)
                    }
                    ForEach(matches) { med in
                        NavigationLink { MedicineDetailView(medicine: med) } label: {
                            MedicineCompactRow(medicine: med, status: cabinet.status(for: med), timeLabel: med.isPRN ? "PRN" : "")
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 22).padding(.top, 4).padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .toolbar(.hidden)
        .onAppear { focused = true }
    }
}
