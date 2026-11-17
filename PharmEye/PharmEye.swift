import SwiftUI

@main
struct PharmEyeApp: App {
    // Real, persisted cabinet. Debug builds seed the demo medicines once on first
    // launch (see CabinetStore.init); release builds start empty.
    @StateObject private var cabinet = CabinetStore.shared
    @Environment(\.scenePhase) private var scenePhase

    init() { PEFonts.register() }

    var body: some Scene {
        WindowGroup {
            OnboardingFlowView()
                .environmentObject(cabinet)
                .modifier(AppLockGate())
                .task { ReminderScheduler.scheduleAll(cabinet.medicines) }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        cabinet.rollOverToToday()
                        Task { await AuthStore.shared.refreshIfNeeded() }
                    }
                }
        }
    }
}
