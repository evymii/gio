import CoreLocation
import Foundation

// One typed function per Gapi endpoint. Screens call these — never raw URLs.

private struct LatLngBody: Encodable { let lat: Double; let lng: Double }

extension APIClient {
    // MARK: Auth (no token needed)
    func signup(name: String, email: String, password: String) async throws -> AuthResponse {
        struct Body: Encodable { let name, email, password: String }
        return try await send("POST", "api/v1/auth/signup", body: Body(name: name, email: email, password: password), authed: false)
    }

    func login(email: String, password: String) async throws -> AuthResponse {
        struct Body: Encodable { let email, password: String }
        return try await send("POST", "api/v1/auth/login", body: Body(email: email, password: password), authed: false)
    }

    func logout(refreshToken: String) async throws {
        try await sendVoid("POST", "api/v1/auth/logout", body: ["refreshToken": refreshToken], authed: false)
    }

    func health() async throws -> Health {
        try await send("GET", "health", authed: false, acceptStatus: [503])
    }

    // MARK: Me
    func me() async throws -> Me { try await send("GET", "api/v1/users/me") }

    func updateMe(name: String? = nil, avatar: String? = nil, locationSharing: String? = nil) async throws -> Me {
        struct Body: Encodable { let name: String?; let avatar: String?; let locationSharing: String? }
        return try await send("PATCH", "api/v1/users/me", body: Body(name: name, avatar: avatar, locationSharing: locationSharing))
    }

    func searchUsers(_ q: String) async throws -> [PublicUser] {
        try await send("GET", "api/v1/users/search", query: ["q": q])
    }

    // MARK: Location sharing & friends
    func uploadLocations(_ points: [CLLocation]) async throws {
        struct Point: Encodable { let lat, lng, accuracyMeters: Double; let recordedAt: Date }
        struct Body: Encodable { let points: [Point] }
        struct Result: Decodable { let accepted: Int }
        let body = Body(points: points.map {
            Point(lat: $0.coordinate.latitude, lng: $0.coordinate.longitude,
                  accuracyMeters: max(0, $0.horizontalAccuracy), recordedAt: $0.timestamp)
        })
        let _: Result = try await send("POST", "api/v1/locations", body: body)
    }

    func friendLocations() async throws -> [FriendLocation] { try await send("GET", "api/v1/locations/friends") }
    func friends() async throws -> FriendsList { try await send("GET", "api/v1/friends") }

    func sendFriendRequest(to userId: String) async throws {
        struct R: Decodable { let status: String }
        let _: R = try await send("POST", "api/v1/friends/requests", body: ["userId": userId])
    }

    func acceptFriend(_ friendshipId: String) async throws {
        struct R: Decodable { let status: String }
        let _: R = try await send("POST", "api/v1/friends/\(friendshipId)/accept")
    }

    func removeFriendship(_ friendshipId: String) async throws {
        try await sendVoid("DELETE", "api/v1/friends/\(friendshipId)")
    }

    // MARK: Spots, check-ins, quests
    func nearbySpots(at c: CLLocationCoordinate2D, radius: Int = 1500) async throws -> [Spot] {
        try await send("GET", "api/v1/spots/nearby", query: ["lat": "\(c.latitude)", "lng": "\(c.longitude)", "radius": "\(radius)"])
    }

    func checkIn(spotId: String, at location: CLLocation) async throws -> CheckinResult {
        struct Body: Encodable { let spotId: String; let lat, lng, accuracyMeters: Double }
        return try await send("POST", "api/v1/checkins", body: Body(spotId: spotId, lat: location.coordinate.latitude,
                                                                  lng: location.coordinate.longitude,
                                                                  accuracyMeters: max(0, location.horizontalAccuracy)))
    }

    func quests() async throws -> [Quest] { try await send("GET", "api/v1/quests") }
    func claimQuest(_ id: String) async throws -> ClaimResult { try await send("POST", "api/v1/quests/\(id)/claim") }

    func leaderboard(period: String = "weekly") async throws -> Leaderboard {
        try await send("GET", "api/v1/leaderboards", query: ["period": period, "limit": "50"])
    }

    func allSpots(type: String? = nil) async throws -> [Spot] {
        try await send("GET", "api/v1/spots", query: ["type": type])
    }

    func checkinHistory(limit: Int = 50) async throws -> [CheckinHistoryItem] {
        try await send("GET", "api/v1/checkins", query: ["limit": "\(limit)"])
    }

    func dashboard(at c: CLLocationCoordinate2D?) async throws -> Dashboard {
        try await send("GET", "api/v1/dashboard", query: ["lat": c.map { "\($0.latitude)" }, "lng": c.map { "\($0.longitude)" }])
    }
}
