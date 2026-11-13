import Foundation

/// Holds the access/refresh tokens (persisted in the Keychain) and refreshes
/// them when the access token expires. Concurrent refreshes are coalesced.
actor TokenStore {
    struct Tokens: Sendable { var access: String; var refresh: String }

    private let persist: Bool
    private var tokens: Tokens?
    private var refreshTask: Task<Bool, Never>?

    init(persist: Bool = true) {
        self.persist = persist
        if persist, let a = Keychain.get("accessToken"), let r = Keychain.get("refreshToken") {
            tokens = Tokens(access: a, refresh: r)
        }
    }

    var accessToken: String? { tokens?.access }
    var refreshToken: String? { tokens?.refresh }
    var hasSession: Bool { tokens != nil }

    func set(access: String, refresh: String) {
        tokens = Tokens(access: access, refresh: refresh)
        if persist {
            Keychain.set(access, for: "accessToken")
            Keychain.set(refresh, for: "refreshToken")
        }
    }

    func clear() {
        tokens = nil
        if persist {
            Keychain.set(nil, for: "accessToken")
            Keychain.set(nil, for: "refreshToken")
        }
    }

    /// Exchanges the refresh token for new tokens. Returns false if the session is over.
    func refresh(baseURL: URL, session: URLSession) async -> Bool {
        if let refreshTask { return await refreshTask.value }
        guard let refresh = tokens?.refresh else { return false }
        let task = Task<Bool, Never> {
            var req = URLRequest(url: baseURL.appending(path: "api/v1/auth/refresh"), timeoutInterval: 15)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try? JSONEncoder().encode(["refreshToken": refresh])
            guard let (data, resp) = try? await session.data(for: req),
                  (resp as? HTTPURLResponse)?.statusCode == 200,
                  let env = try? APIClient.decoder.decode(APIClient.Envelope<AuthResponse>.self, from: data)
            else { return false }
            self.set(access: env.data.accessToken, refresh: env.data.refreshToken)
            return true
        }
        refreshTask = task
        let ok = await task.value
        refreshTask = nil
        if !ok { clear() }
        return ok
    }
}
