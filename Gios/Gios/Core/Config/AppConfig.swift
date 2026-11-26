import Foundation

/// API base URL: build setting (Debug → localhost, Release → deployed), overridable at runtime.
final class AppConfig: @unchecked Sendable {
    private static let overrideKey = "gapi.baseURL.override"
    private let defaults: UserDefaults
    let buildBaseURL: URL

    var baseURL: URL {
        get { defaults.string(forKey: Self.overrideKey).flatMap(URL.init(string:)) ?? buildBaseURL }
        set {
            if newValue == buildBaseURL { defaults.removeObject(forKey: Self.overrideKey) }
            else { defaults.set(newValue.absoluteString, forKey: Self.overrideKey) }
        }
    }

    /// Stable per-install id used to register this phone (PUT /devices).
    var deviceId: String {
        if let id = defaults.string(forKey: "gios.deviceId") { return id }
        let id = UUID().uuidString
        defaults.set(id, forKey: "gios.deviceId")
        return id
    }

    init(bundle: Bundle = .main, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let raw = bundle.object(forInfoDictionaryKey: "GAPI_BASE_URL") as? String
        buildBaseURL = raw.flatMap(URL.init(string:)) ?? URL(string: "http://localhost:8080")!
    }
}
