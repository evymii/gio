import Foundation

/// Typed HTTP client for Gapi. Unwraps `{data}` / `{error}` envelopes, attaches
/// the access token, and transparently refreshes it once on a 401.
final class APIClient: @unchecked Sendable {
    let baseURL: URL
    let tokens: TokenStore
    private let session: URLSession
    /// Called (on any thread) when the refresh token is no longer valid.
    var onSessionExpired: (@Sendable () -> Void)?

    init(baseURL: URL, tokens: TokenStore, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.tokens = tokens
        self.session = session
    }

    struct Envelope<T: Decodable>: Decodable { let data: T }
    private struct ErrorEnvelope: Decodable {
        struct Body: Decodable { let code: String; let message: String }
        let error: Body
    }
    struct Empty: Decodable {}

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let s = try decoder.singleValueContainer().decode(String.self)
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = f.date(from: s) { return date }
            f.formatOptions = [.withInternetDateTime]
            if let date = f.date(from: s) { return date }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Bad date \(s)"))
        }
        return d
    }()

    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    /// Sends a request and decodes `data`. `authed: false` for login/signup/health.
    func send<T: Decodable>(_ method: String, _ path: String, query: [String: String?] = [:],
                            body: (any Encodable)? = nil, authed: Bool = true,
                            acceptStatus: Set<Int> = []) async throws -> T {
        try await perform(method, path, query: query, body: body, authed: authed, acceptStatus: acceptStatus, retry: true)
    }

    /// For endpoints that return 204 / no body.
    func sendVoid(_ method: String, _ path: String, body: (any Encodable)? = nil, authed: Bool = true) async throws {
        let _: Empty? = try await perform(method, path, query: [:], body: body, authed: authed, acceptStatus: [], retry: true)
    }

    private func perform<T: Decodable>(_ method: String, _ path: String, query: [String: String?],
                                       body: (any Encodable)?, authed: Bool, acceptStatus: Set<Int>,
                                       retry: Bool) async throws -> T {
        var components = URLComponents(url: baseURL.appending(path: path), resolvingAgainstBaseURL: false)!
        let items = query.compactMap { k, v in v.map { URLQueryItem(name: k, value: $0) } }.sorted { $0.name < $1.name }
        if !items.isEmpty { components.queryItems = items }
        var request = URLRequest(url: components.url!, timeoutInterval: 60) // Render's free tier can take ~50 s to wake
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try Self.encoder.encode(body)
        }
        if authed, let token = await tokens.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let data: Data, response: URLResponse
        do { (data, response) = try await session.data(for: request) }
        catch { throw APIError.unreachable(error.localizedDescription) }
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }

        if http.statusCode == 401 && authed {
            if retry, await tokens.refresh(baseURL: baseURL, session: session) {
                return try await perform(method, path, query: query, body: body, authed: authed, acceptStatus: acceptStatus, retry: false)
            }
            onSessionExpired?()
            throw APIError.sessionExpired
        }
        if http.statusCode == 204 || data.isEmpty {
            if let empty = Empty() as? T { return empty }
            if let none = Optional<Empty>.none as? T { return none }
            throw APIError.invalidResponse
        }
        if (200..<300).contains(http.statusCode) || acceptStatus.contains(http.statusCode) {
            do { return try Self.decoder.decode(Envelope<T>.self, from: data).data }
            catch { throw APIError.decoding(String(describing: error)) }
        }
        if let env = try? Self.decoder.decode(ErrorEnvelope.self, from: data) {
            throw APIError.server(status: http.statusCode, code: env.error.code, message: env.error.message)
        }
        throw APIError.server(status: http.statusCode, code: "HTTP_\(http.statusCode)",
                              message: HTTPURLResponse.localizedString(forStatusCode: http.statusCode))
    }
}
