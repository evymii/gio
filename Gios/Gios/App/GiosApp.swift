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
        InAppMessages.printInstallationID()
        #endif
        application.registerForRemoteNotifications()
        return true
    }

    // Phone auth verifies the app with a silent push (real devices) or reCAPTCHA (fallback).
    // A SwiftUI app has to hand those to Firebase explicitly.

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        guard FirebaseApp.app() != nil else { return }
        Auth.auth().setAPNSToken(deviceToken, type: .unknown)
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        if FirebaseApp.app() != nil, Auth.auth().canHandleNotification(userInfo) {
            completionHandler(.noData)
            return
        }
        completionHandler(.noData)
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        FirebaseApp.app() != nil && Auth.auth().canHandle(url)
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
                .task { env.remote.start() }
        }
    }
}
