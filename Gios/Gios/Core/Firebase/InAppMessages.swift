import FirebaseCore
import FirebaseInAppMessaging
import FirebaseInstallations

/// Firebase In-App Messaging: popups, banners and cards you design in the Firebase console
/// (Engage → Messaging → New campaign → In-App Messaging). They appear when an Analytics event
/// fires — e.g. on app open, or after `check_in` / `quest_claim` (see Telemetry) — with no new build.
enum InAppMessages {
    /// Keep messages away from login and the first-time "pick a name" step.
    static func update(signedIn: Bool, onboarding: Bool) {
        guard FirebaseApp.app() != nil else { return }
        InAppMessaging.inAppMessaging().messageDisplaySuppressed = !signedIn || onboarding
    }

    #if DEBUG
    /// Prints this install's ID — paste it in the console's "Test on device" to preview a campaign.
    static func printInstallationID() {
        guard FirebaseApp.app() != nil else { return }
        Task {
            if let id = try? await Installations.installations().installationID() { print("FIREBASE_INSTALLATION_ID \(id)") }
        }
    }
    #endif
}
