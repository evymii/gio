import FirebaseAnalytics
import FirebaseCore
import FirebaseCrashlytics
import Foundation

/// Analytics events + Crashlytics context in one place. Screens call `Telemetry.log(.checkIn(...))`;
/// nothing here throws or blocks, and it's a no-op when Firebase isn't configured (tests, fresh clones).
/// See events live: Firebase console → Analytics → DebugView (Debug builds pass -FIRDebugEnabled).
enum Telemetry {
    enum Event {
        case login(method: String, isNew: Bool)
        case checkIn(spotType: String, verified: Bool, xp: Int)
        case levelUp(level: Int)
        case questClaim(quest: String, xp: Int)
        case friendRequest
        case friendAccept
        case mapOpen(spots: Int, friendsOnline: Int)
        /// Home shown to a signed-in player — the trigger to use for In-App Messaging campaigns.
        case homeOpen

        var name: String {
            switch self {
            case let .login(_, isNew): isNew ? AnalyticsEventSignUp : AnalyticsEventLogin
            case .checkIn: "check_in"
            case .levelUp: AnalyticsEventLevelUp
            case .questClaim: "quest_claim"
            case .friendRequest: "friend_request"
            case .friendAccept: "friend_accept"
            case .mapOpen: "map_open"
            case .homeOpen: "home_open"
            }
        }

        var parameters: [String: Any] {
            switch self {
            case let .login(method, _): [AnalyticsParameterMethod: method]
            case let .checkIn(type, verified, xp): ["spot_type": type, "verified": verified ? 1 : 0, "xp": xp]
            case let .levelUp(level): [AnalyticsParameterLevel: level]
            case let .questClaim(quest, xp): ["quest": quest, "xp": xp]
            case .friendRequest, .friendAccept, .homeOpen: [:]
            case let .mapOpen(spots, online): ["spots": spots, "friends_online": online]
            }
        }
    }

    private static var enabled: Bool { FirebaseApp.app() != nil }

    static func log(_ event: Event) {
        guard enabled else { return }
        Analytics.logEvent(event.name, parameters: event.parameters)
        Crashlytics.crashlytics().log("event \(event.name)") // breadcrumb shown with any later crash
    }

    /// Ties analytics + crash reports to the Gapi user id (never the phone number).
    static func identify(userId: String?) {
        guard enabled else { return }
        Analytics.setUserID(userId)
        Crashlytics.crashlytics().setUserID(userId ?? "")
    }

    static func record(_ error: Error) {
        guard enabled else { return }
        Crashlytics.crashlytics().record(error: error)
    }
}
