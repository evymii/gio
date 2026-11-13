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
                    AuthView().transition(.opacity)
                case .signedIn:
                    MainTabView().transition(.opacity)
                case let .offline(reason):
                    OfflineView(reason: reason) { Task { await env.session.restore() } }
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: splashDone)
        .animation(.easeInOut(duration: 0.3), value: stateKey)
        .task {
            async let restore: Void = env.session.restore()
            try? await Task.sleep(for: .seconds(1.2)) // let the splash breathe
            await restore
            #if DEBUG
            // Screenshot/QA hook: `-demoLogin` signs in the seeded demo account.
            if ProcessInfo.processInfo.arguments.contains("-demoLogin"), env.session.state == .signedOut {
                try? await env.session.login(email: "demo@gios.app", password: "campus123")
            }
            #endif
            splashDone = true
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
        ContentUnavailableView {
            Label("Can't reach Gios", systemImage: "wifi.slash")
        } description: {
            Text(reason)
        } actions: {
            Button("Try again", action: retry).buttonStyle(.borderedProminent)
        }
    }
}
