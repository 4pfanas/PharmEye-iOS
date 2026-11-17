import SwiftUI

/// Owns 01→04, then hands off to RootTabView. Kept as its own step-machine (rather
/// than a NavigationStack) since Splash auto-advances and the prototype treats these
/// as one continuous flow, not a stack the user pages back through freely.
struct OnboardingFlowView: View {
    enum Step: Equatable { case splash, getStarted, signIn, profileSetup, done }
    @AppStorage("onboarding.done") private var onboardingDone = false
    @State private var step: Step = UserDefaults.standard.bool(forKey: "onboarding.done") ? .done : .splash

    var body: some View {
        Group {
            switch step {
            case .splash: SplashView { step = .getStarted }
            case .getStarted: GetStartedView { step = .signIn }
            case .signIn: SignInView { step = .profileSetup }
            case .profileSetup: ProfileSetupView { UserDefaults.standard.set(true, forKey: "onboarding.done"); step = .done }
            case .done: RootTabView()
            }
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.25), value: step)
    }
}
