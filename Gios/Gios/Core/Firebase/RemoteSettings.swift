import FirebaseCore
import FirebaseRemoteConfig
import Foundation
import Observation

/// App-side settings you can change from Firebase console → Remote Config without a new build.
/// (Game rules like XP, check-in radius and cooldown stay on the server so players can't cheat.)
///
/// | Key                    | Default | What it does                                         |
/// |------------------------|---------|------------------------------------------------------|
/// | home_banner            | ""      | Announcement shown on Home (empty = hidden)          |
/// | map_refresh_seconds    | 30      | How often the map reloads spots + friends            |
/// | map_spot_radius_meters | 3000    | How far around you the map loads spots               |
/// | email_login_enabled    | true    | Show "Sign in with email" on the welcome screen      |
@MainActor
@Observable
final class RemoteSettings {
    private(set) var homeBanner = ""
    private(set) var mapRefreshSeconds = 30
    private(set) var mapSpotRadiusMeters = 3000
    private(set) var emailLoginEnabled = true

    private static let defaults: [String: NSObject] = [
        "home_banner": "" as NSString,
        "map_refresh_seconds": 30 as NSNumber,
        "map_spot_radius_meters": 3000 as NSNumber,
        "email_login_enabled": true as NSNumber,
    ]

    /// Applies cached values immediately, then fetches fresh ones in the background.
    func start() {
        guard FirebaseApp.app() != nil else { return }
        let rc = RemoteConfig.remoteConfig()
        let settings = RemoteConfigSettings()
        #if DEBUG
        settings.minimumFetchInterval = 0 // see console changes on the next launch while testing
        #else
        settings.minimumFetchInterval = 3600
        #endif
        rc.configSettings = settings
        rc.setDefaults(Self.defaults)
        apply(rc)
        Task {
            _ = try? await rc.fetchAndActivate()
            apply(rc)
        }
    }

    private func apply(_ rc: RemoteConfig) {
        homeBanner = rc["home_banner"].stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        mapRefreshSeconds = min(max(rc["map_refresh_seconds"].numberValue.intValue, 10), 600)
        mapSpotRadiusMeters = min(max(rc["map_spot_radius_meters"].numberValue.intValue, 300), 20_000)
        emailLoginEnabled = rc["email_login_enabled"].boolValue
    }
}
