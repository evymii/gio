import Foundation
import Observation

/// Who is logged in. Restores the session from the Keychain on launch.
@MainActor
@Observable
final class SessionStore {
    enum State: Equatable {
        case loading
        case signedOut
        case signedIn(Me)
        case offline(String) // have a session but can't reach the server
    }

    private(set) var state: State = .loading
    /// A brand-new phone account: show the "pick a name & look" step once.
    var needsProfile = false
    private let api: APIClient
    private let tokens: TokenStore

    init(api: APIClient, tokens: TokenStore) {
        self.api = api
        self.tokens = tokens
    }

    var me: Me? { if case let .signedIn(me) = state { me } else { nil } }

    func restore() async {
        guard await tokens.hasSession else { state = .signedOut; return }
        state = .loading
        do {
            state = .signedIn(try await api.me())
        } catch APIError.sessionExpired {
            state = .signedOut
        } catch let APIError.unreachable(reason) {
            state = .offline(reason)
        } catch {
            state = .signedOut
        }
    }

    func login(email: String, password: String) async throws {
        try await finish(api.login(email: email, password: password))
        Telemetry.log(.login(method: "email", isNew: false))
    }

    func signup(name: String, email: String, password: String) async throws {
        try await finish(api.signup(name: name, email: email, password: password))
        Telemetry.log(.login(method: "email", isNew: true))
    }

    /// Phone sign-in: Firebase verified the number; Gapi turns that into a session.
    func loginWithFirebase(idToken: String) async throws {
        let auth = try await api.firebaseLogin(idToken: idToken)
        needsProfile = auth.isNew == true
        await finish(auth)
        Telemetry.log(.login(method: "phone", isNew: needsProfile))
    }

    private func finish(_ auth: AuthResponse) async {
        await tokens.set(access: auth.accessToken, refresh: auth.refreshToken)
        state = .signedIn(auth.user)
    }

    func update(_ me: Me) { state = .signedIn(me) }

    func refreshMe() async {
        if let me = try? await api.me() { state = .signedIn(me) }
    }

    func logout() async {
        if let refresh = await tokens.refreshToken { try? await api.logout(refreshToken: refresh) }
        await tokens.clear()
        PhoneAuth.signOut()
        needsProfile = false
        state = .signedOut
    }

    /// The refresh token was rejected — back to the login screen.
    func expire() async {
        await tokens.clear()
        state = .signedOut
    }
}
