import SwiftUI

@main
struct GiosApp: App {
    @State private var env = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(env)
                .tint(Theme.Colors.yellow)
                .preferredColorScheme(.dark)
        }
    }
}
