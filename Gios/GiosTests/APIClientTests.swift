import Foundation
import Testing
@testable import Gios

/// Intercepts URLSession so APIClient can be tested without a server.
final class StubProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: ((URLRequest) -> (Int, String))?
    nonisolated(unsafe) static var requests: [URLRequest] = []

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.requests.append(request)
        guard let (status, body) = Self.handler?(request) else {
            client?.urlProtocol(self, didFailWithError: URLError(.cannotConnectToHost)); return
        }
        let resp = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

private let meJSON = """
{"id":"u1","name":"Demo Student","email":"demo@gios.app","avatar":"avatar-1","level":2,"xp":150,"levelStartXp":100,"nextLevelXp":400,"locationSharing":"friends","createdAt":"2026-11-13T02:02:14.425Z"}
"""
private func authJSON(_ access: String, _ refresh: String) -> String {
    #"{"data":{"user":"# + meJSON + #","accessToken":""# + access + #"","refreshToken":""# + refresh + #"","expiresIn":900}}"#
}

@Suite(.serialized)
struct APIClientTests {
    let tokens = TokenStore(persist: false)
    let api: APIClient

    init() {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.protocolClasses = [StubProtocol.self]
        api = APIClient(baseURL: URL(string: "http://test.local")!, tokens: tokens, session: URLSession(configuration: cfg))
        StubProtocol.requests = []
    }

    @Test func loginDecodesUserAndTokens() async throws {
        StubProtocol.handler = { _ in (200, authJSON("a1", "r1")) }
        let auth = try await api.login(email: "demo@gios.app", password: "campus123")
        #expect(auth.user.name == "Demo Student")
        #expect(auth.user.levelProgress == 50.0 / 300.0)
        #expect(StubProtocol.requests.first?.value(forHTTPHeaderField: "Authorization") == nil)
    }

    @Test func authedRequestsSendBearerToken() async throws {
        await tokens.set(access: "a1", refresh: "r1")
        StubProtocol.handler = { _ in (200, #"{"data":"# + meJSON + "}") }
        _ = try await api.me()
        #expect(StubProtocol.requests.last?.value(forHTTPHeaderField: "Authorization") == "Bearer a1")
    }

    @Test func expiredAccessTokenIsRefreshedAndRetried() async throws {
        await tokens.set(access: "old", refresh: "r1")
        StubProtocol.handler = { req in
            if req.url?.path == "/api/v1/auth/refresh" { return (200, authJSON("new", "r2")) }
            let token = req.value(forHTTPHeaderField: "Authorization")
            return token == "Bearer new" ? (200, #"{"data":"# + meJSON + "}")
                                         : (401, #"{"error":{"code":"TOKEN_INVALID","message":"expired"}}"#)
        }
        let me = try await api.me()
        #expect(me.id == "u1")
        #expect(await tokens.accessToken == "new")
        #expect(await tokens.refreshToken == "r2")
        #expect(StubProtocol.requests.map { $0.url!.path } == ["/api/v1/users/me", "/api/v1/auth/refresh", "/api/v1/users/me"])
    }

    @Test func deadRefreshTokenEndsTheSession() async {
        await tokens.set(access: "old", refresh: "dead")
        StubProtocol.handler = { _ in (401, #"{"error":{"code":"REFRESH_INVALID","message":"Please log in again"}}"#) }
        let expired = Flag()
        api.onSessionExpired = { expired.set() }
        await #expect(throws: APIError.sessionExpired) { _ = try await api.me() }
        #expect(expired.value)
        #expect(await tokens.hasSession == false)
    }

    @Test func serverErrorsCarryCodeAndMessage() async {
        StubProtocol.handler = { _ in (409, #"{"error":{"code":"EMAIL_TAKEN","message":"An account with this email already exists"}}"#) }
        do {
            _ = try await api.signup(name: "A", email: "a@b.c", password: "password123")
            Issue.record("expected error")
        } catch let e as APIError {
            #expect(e.code == "EMAIL_TAKEN")
            #expect(e.localizedDescription == "An account with this email already exists")
        } catch { Issue.record("wrong error \(error)") }
    }

    @Test func dashboardDecodes() async throws {
        await tokens.set(access: "a1", refresh: "r1")
        let spot = #"{"id":"s1","slug":"main-gate","name":"Main Gate","type":"landmark","description":"","lat":37.33,"lng":-122.0,"geohash":"9q9","radiusMeters":60,"rewardXp":20,"active":true,"distanceMeters":12,"inRange":true,"cooldownUntil":null}"#
        let body = #"{"data":{"user":"# + meJSON + #","position":{"lat":37.33,"lng":-122.0},"region":{"id":"r","slug":"north-campus","name":"North Campus"},"stats":{"checkinsTotal":4,"checkinsThisWeek":2,"uniqueSpots":4,"friends":4},"nearbySpots":["# + spot + #"],"quests":[{"id":"q","slug":"coffee-run","title":"Coffee Run","description":"d","goal":{"type":"spot_type","target":2,"spotType":"cafe"},"rewardXp":80,"reward":{"id":"x","name":"Café Regular","type":"avatar","icon":"cup.and.saucer.fill"},"progress":2,"status":"completed","completedAt":null,"claimedAt":null}],"friendsOnline":{"count":1,"total":4,"users":[{"user":{"id":"f","name":"Mio","avatar":"avatar-2","level":3},"lastSeenAt":"2026-11-13T02:02:14.425Z","distanceMeters":120}]},"leaderboard":{"period":"weekly","rank":3,"score":160,"top":[]},"events":[{"id":"e","slug":"welcome-week","title":"Welcome Week","description":"2x","regionId":null,"startsAt":"2026-11-11T02:02:14.425Z","endsAt":"2026-11-25T02:02:14.425Z","xpMultiplier":2,"isActive":true}]}}"#
        StubProtocol.handler = { _ in (200, body) }
        let d = try await api.dashboard(at: .init(latitude: 37.33, longitude: -122.0))
        #expect(d.nearbySpots.first?.inRange == true)
        #expect(d.quests.first?.isClaimable == true)
        #expect(d.friendsOnline.users.first?.user.name == "Mio")
        #expect(d.events.first?.xpMultiplier == 2)
        let q = StubProtocol.requests.last?.url?.query ?? ""
        #expect(q.contains("lat=37.33") && q.contains("lng=-122.0"))
    }
}

final class Flag: @unchecked Sendable {
    private let lock = NSLock()
    private var _value = false
    var value: Bool { lock.withLock { _value } }
    func set() { lock.withLock { _value = true } }
}
