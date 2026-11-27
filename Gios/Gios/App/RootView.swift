import SwiftUI

/// User flow: Splash → (restore session) → Auth or Main tabs.
struct RootView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var splashDone = false

    var body: some View {
        ZStack {
            if !splashDone {
                SplashView()
                    .transition(.opacity)
            } else {
                switch env.session.state {
                case .loading:
                    SplashView().transition(.opacity)
                case .signedOut:
                    AuthFlow().transition(.asymmetric(insertion: .push(from: .leading), removal: .push(from: .trailing)))
                case .signedIn:
                    MainTabView().transition(.asymmetric(insertion: .push(from: .trailing), removal: .push(from: .leading)))
                case let .offline(reason):
                    OfflineView(reason: reason) { Task { await env.session.restore() } }
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: splashDone)
        .animation(.spring(response: 0.5, dampingFraction: 0.9), value: stateKey)
        .background(Theme.Colors.background.ignoresSafeArea())
        .task {
            async let restore: Void = env.session.restore()
            try? await Task.sleep(for: .seconds(1.2)) // let the splash breathe
            await restore
            #if DEBUG
            // Screenshot/QA hook: `-demoLogin` signs in the seeded demo account.
            if ProcessInfo.processInfo.arguments.contains("-demoLogin"), env.session.state == .signedOut {
                try? await env.session.login(email: "demo@gios.app", password: "campus123")
            }
            // `-phoneLogin` runs the real phone flow with the Firebase console test number (no SMS).
            if ProcessInfo.processInfo.arguments.contains("-phoneLogin") {
                if env.session.me != nil { await env.session.logout() }
                do {
                    let id = try await PhoneAuth.sendCode(to: "+97699999999")
                    let token = try await PhoneAuth.confirm(verificationID: id, code: "123456")
                    try await env.session.loginWithFirebase(idToken: token)
                    print("QA phoneLogin: signed in, isNew=\(env.session.needsProfile)")
                } catch {
                    print("QA phoneLogin failed: \(PhoneAuth.message(for: error))")
                }
            }
            #endif
            splashDone = true
        }
        .sheet(isPresented: Bindable(env.session).needsProfile) {
            NavigationStack { EditProfileView(isWelcome: true) }
                .interactiveDismissDisabled()
        }
        .onChange(of: "\(env.session.me?.id ?? "")|\(env.session.needsProfile)", initial: true) {
            InAppMessages.update(signedIn: env.session.me != nil, onboarding: env.session.needsProfile)
        }
        .onChange(of: env.session.me?.id) { _, id in
            if id != nil { Task { await env.didSignIn() } }
        }
    }

    private var stateKey: String {
        switch env.session.state {
        case .loading: "loading"
        case .signedOut: "out"
        case .signedIn: "in"
        case .offline: "offline"
        }
    }
}

private struct OfflineView: View {
    let reason: String
    let retry: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            Spacer()
            LineBadge(icon: "wifi.slash", color: Theme.Colors.red, size: 72)
            StackedTitle(primary: "Can't reach", secondary: "the campus", size: 44)
            Text(reason).font(Theme.Fonts.body).foregroundStyle(Theme.Colors.textSecondary)
            Spacer()
            Button("Try again", action: retry).buttonStyle(PillButtonStyle())
        }
        .padding(Theme.Spacing.l)
    }
}
