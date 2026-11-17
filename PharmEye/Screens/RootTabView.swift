import SwiftUI

/// The bottom dock from the prototype: Home / Cabinet / Symptoms / Profile.
/// Scanner, Notifications and Reminders are pushed from within those tabs
/// rather than living in the dock themselves — matching the header-button
/// placement agreed in the design pass.
struct RootTabView: View {
    var body: some View {
        TabView {
            NavigationStack { HomeView() }
                .tabItem { Label("Home", systemImage: "house.fill") }

            NavigationStack { CabinetView() }
                .tabItem { Label("Cabinet", systemImage: "pills.fill") }

            NavigationStack { SymptomsView() }
                .tabItem { Label("Symptoms", systemImage: "waveform.path.ecg") }

            NavigationStack { ProfileView() }
                .tabItem { Label("Profile", systemImage: "person.fill") }
        }
        .tint(PETheme.mar)
        .onAppear {
            // Opaque paper (or night) tab bar, flat with a hairline ink rule on top.
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(PETheme.bg)
            appearance.shadowColor = UIColor(PETheme.line2)
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}
