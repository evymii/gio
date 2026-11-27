import FirebaseAuth
import FirebaseCore
import SwiftUI

/// Firebase needs to be configured from an app delegate, before any screen asks for it.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // GoogleService-Info.plist is git-ignored; without it (e.g. unit tests, fresh clone) we skip Firebase.
        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else { return true }
        FirebaseApp.configure()
        #if DEBUG
        // Simulator: the Firebase console's test phone numbers sign in without APNs or reCAPTCHA (and send no SMS).
        Auth.auth().settings?.isAppVerificationDisabledForTesting = true
        #endif
        return true
    }
}

@main
struct GiosApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
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
