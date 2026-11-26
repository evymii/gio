import Foundation

/// API base URL: build setting (the deployed Gapi on Render), overridable at runtime.
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

    init(bundle: Bundle = .main, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let raw = bundle.object(forInfoDictionaryKey: "GAPI_BASE_URL") as? String
        buildBaseURL = raw.flatMap(URL.init(string:)) ?? URL(string: "https://gio-wbqj.onrender.com")!
    }
}
