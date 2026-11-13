import Foundation
import Observation

/// App-wide dependencies, created once and injected with `.environment(...)`.
@MainActor
@Observable
final class AppEnvironment {
    let config: AppConfig
    let tokens: TokenStore
    let api: APIClient
    let session: SessionStore
    let location: LocationService
    @ObservationIgnored private let sharer: LocationSharer

    init(config: AppConfig = AppConfig(), tokens: TokenStore = TokenStore()) {
        self.config = config
        self.tokens = tokens
        let api = APIClient(baseURL: config.baseURL, tokens: tokens)
        self.api = api
        let session = SessionStore(api: api, tokens: tokens)
        self.session = session
        self.location = LocationService()
        self.sharer = LocationSharer(api: api)

        api.onSessionExpired = { Task { @MainActor in await session.expire() } }
        location.onUpdate = { [weak self] loc in self?.sharer.handle(loc) }
    }

    /// Call after login / profile changes: starts location + sharing as appropriate.
    func didSignIn() async {
        location.start()
        sharer.isEnabled = session.me?.isSharing ?? false
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        try? await api.registerDevice(deviceId: config.deviceId, locationPermission: location.permissionName, appVersion: version)
        if let loc = location.location { sharer.handle(loc) }
    }

    func setSharing(_ on: Bool) async throws {
        let me = try await api.updateMe(locationSharing: on ? "friends" : "off")
        session.update(me)
        sharer.isEnabled = on
        if on, let loc = location.location { sharer.handle(loc) }
    }

    func signOut() async {
        sharer.isEnabled = false
        location.stop()
        await session.logout()
    }
}
