import SwiftUI

/// 06 / 06b — Cabinet: every medicine as a card, with a count summary under the title,
/// and the empty state for a fresh cabinet.
struct CabinetView: View {
    @EnvironmentObject private var cabinet: CabinetStore
    @Environment(\.dismiss) private var dismiss
    /// True when pushed from Home's "See all" rather than shown as the Cabinet tab.
    var showsBack = false
    @State private var showScanner = false
    @State private var showAddManually = false

    var body: some View {
        ZStack {
            PEPaperBackground()
            if cabinet.medicines.isEmpty {
                CabinetEmptyView(showScanner: $showScanner, showAddManually: $showAddManually)
            } else {
                VStack(spacing: 0) {
                    header
                    CabinetCardList()
                }
            }
        }
        .toolbar(.hidden)
        .sheet(isPresented: $showScanner) {
            ScannerView { medicine in cabinet.addScannedMedicine(medicine) }
        }
        .sheet(isPresented: $showAddManually) {
            AddMedicineView()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                if showsBack {
                    Button { dismiss() } label: { PEHeaderIconButton(systemImage: "chevron.left") }
                        .accessibilityLabel("Back")
                }
                Text("Cabinet").font(PETheme.display(28)).accessibilityAddTraits(.isHeader).foregroundStyle(PETheme.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                HStack(spacing: 9) {
                    Button { showAddManually = true } label: { PEHeaderIconButton(systemImage: "plus") }
                        .accessibilityLabel("Add a medicine")
                    Button { showScanner = true } label: { PEHeaderIconButton(systemImage: "barcode.viewfinder", square: true) }
                    NavigationLink { NotificationsView() } label: { PEHeaderIconButton(systemImage: "bell.fill", badge: true) }
                }
            }
            summary
        }
        .padding(.horizontal, 22).padding(.top, 8)
    }

    /// Medicine count (and how many still need attention today), where the old
    /// Cards/Compact switch used to sit.
    private var summary: some View {
        let due = cabinet.medicines.filter { [.missed, .dueSoon].contains(cabinet.status(for: $0)) }.count
        return HStack(spacing: 8) {
            Label("\(cabinet.medicines.count) \(cabinet.medicines.count == 1 ? "medicine" : "medicines")", systemImage: "pills.fill")
                .font(PETheme.semibold(12.5)).foregroundStyle(PETheme.onMar)
                .padding(.horizontal, 13).padding(.vertical, 8)
                .peSurface(PETheme.mar, radius: PETheme.radiusPill, seed: 4, stroke: PETheme.textPrimary)
            if due > 0 {
                Label("\(due) need attention", systemImage: "exclamationmark.circle.fill")
                    .font(PETheme.semibold(12.5)).foregroundStyle(PETheme.rose)
                    .padding(.horizontal, 13).padding(.vertical, 8)
                    .peSurface(PETheme.roseDim, radius: PETheme.radiusPill, seed: 9, stroke: PETheme.rose.opacity(0.5))
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// 06 default card view.
private struct CabinetCardList: View {
    @EnvironmentObject private var cabinet: CabinetStore
    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(cabinet.medicines) { med in
                    NavigationLink { MedicineDetailView(medicine: med) } label: {
                        MedicineCard(medicine: med, status: cabinet.status(for: med))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 22).padding(.top, 16).padding(.bottom, 30)
        }
    }
}

/// 06b — empty Cabinet (first run).
struct CabinetEmptyView: View {
    @Binding var showScanner: Bool
    @Binding var showAddManually: Bool

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("0 MEDICINES").font(PETheme.bold(11)).foregroundStyle(PETheme.textTertiary)
                    Text("Cabinet").font(PETheme.display(28)).accessibilityAddTraits(.isHeader).foregroundStyle(PETheme.textPrimary)
                }
                Spacer()
                Button { showScanner = true } label: {
                    PEHeaderIconButton(systemImage: "barcode.viewfinder", square: true)
                }
            }
            .padding(.horizontal, 22).padding(.top, 8)

            Spacer()
            Image(systemName: "pills.fill")
                .font(.system(size: 30)).foregroundStyle(PETheme.mar2)
                .frame(width: 84, height: 84)
                .background(PETheme.mar.opacity(0.14), in: RoundedRectangle(cornerRadius: 26))
            Text("Your cabinet is empty").font(PETheme.bold(20)).foregroundStyle(PETheme.textPrimary)
            Text("Scan the barcode on a box or add one by hand — either way, it only takes a few seconds.")
                .font(PETheme.prose(14.5)).foregroundStyle(PETheme.textSecondary)
                .multilineTextAlignment(.center).padding(.horizontal, 34)
            Button("Scan a medicine") { showScanner = true }.buttonStyle(PEPrimaryButtonStyle()).padding(.horizontal, 55)
            Button("Add manually") { showAddManually = true }.buttonStyle(PESecondaryButtonStyle()).padding(.horizontal, 55)
            Spacer()
        }
    }
}
