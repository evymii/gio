import CoreLocation
import Foundation

// Codable mirrors of Gapi's responses. Field names match the JSON exactly.

struct Me: Codable, Hashable, Sendable {
    let id: String
    let name: String
    let email: String
    let avatar: String
    let level: Int
    let xp: Int
    let levelStartXp: Int
    let nextLevelXp: Int
    let locationSharing: String
    let createdAt: Date

    var isSharing: Bool { locationSharing == "friends" }
    var levelProgress: Double {
        let span = Double(nextLevelXp - levelStartXp)
        return span > 0 ? Double(xp - levelStartXp) / span : 0
    }
}

struct PublicUser: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let name: String
    let avatar: String
    let level: Int
}

struct AuthResponse: Codable, Sendable {
    let user: Me
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
}

struct LatLng: Codable, Hashable, Sendable {
    let lat: Double
    let lng: Double
    var coordinate: CLLocationCoordinate2D { .init(latitude: lat, longitude: lng) }
}

struct Spot: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let slug: String
    let name: String
    let type: String
    let description: String
    let lat: Double
    let lng: Double
    let radiusMeters: Double
    let rewardXp: Int
    let active: Bool
    // Present on /spots/nearby and the dashboard:
    let distanceMeters: Double?
    let inRange: Bool?
    let cooldownUntil: Date?

    var coordinate: CLLocationCoordinate2D { .init(latitude: lat, longitude: lng) }
    var isOnCooldown: Bool { (cooldownUntil ?? .distantPast) > .now }
}

struct Quest: Codable, Hashable, Identifiable, Sendable {
    struct Goal: Codable, Hashable, Sendable { let type: String; let target: Int; let spotType: String? }
    struct RewardRef: Codable, Hashable, Sendable { let id: String; let name: String; let type: String; let icon: String }
    let id: String
    let slug: String
    let title: String
    let description: String
    let goal: Goal
    let rewardXp: Int
    let reward: RewardRef?
    let progress: Int
    let status: String

    var isClaimable: Bool { status == "completed" }
    var isClaimed: Bool { status == "claimed" }
    var fraction: Double { goal.target > 0 ? min(1, Double(progress) / Double(goal.target)) : 0 }
}

struct CheckinResult: Codable, Sendable {
    struct Checkin: Codable, Sendable {
        let id: String
        let spot: Spot
        let distanceMeters: Double
        let verified: Bool
        let xpAwarded: Int
        let multiplier: Double
    }
    struct UserXP: Codable, Sendable { let xp: Int; let level: Int; let leveledUp: Bool }
    struct QuestUpdate: Codable, Sendable { let questId: String; let title: String; let progress: Int; let target: Int; let completed: Bool }
    let checkin: Checkin
    let user: UserXP?
    let quests: [QuestUpdate]
    let message: String
}

struct ClaimResult: Codable, Sendable {
    let xpAwarded: Int
    let user: CheckinResult.UserXP
    let reward: Quest.RewardRef?
}

struct FriendLocation: Codable, Hashable, Identifiable, Sendable {
    struct Location: Codable, Hashable, Sendable { let lat: Double; let lng: Double; let accuracyMeters: Double?; let recordedAt: Date }
    let user: PublicUser
    let location: Location
    let online: Bool
    var id: String { user.id }
    var coordinate: CLLocationCoordinate2D { .init(latitude: location.lat, longitude: location.lng) }
}

struct FriendsList: Codable, Sendable {
    struct Item: Codable, Hashable, Identifiable, Sendable {
        let friendshipId: String
        let user: PublicUser
        let since: Date
        var id: String { friendshipId }
    }
    let friends: [Item]
    let incoming: [Item]
    let outgoing: [Item]
}

struct Leaderboard: Codable, Sendable {
    struct Entry: Codable, Hashable, Identifiable, Sendable {
        let rank: Int
        let score: Int
        let user: PublicUser
        let isMe: Bool
        var id: String { user.id }
    }
    struct MyRank: Codable, Sendable { let rank: Int?; let score: Int }
    let period: String
    let entries: [Entry]
    let me: MyRank
}

struct GameEvent: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let slug: String
    let title: String
    let description: String
    let startsAt: Date
    let endsAt: Date
    let xpMultiplier: Double
    let isActive: Bool
}

struct Reward: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let slug: String
    let name: String
    let type: String
    let value: String
    let description: String
    let icon: String
}

struct InventoryEntry: Codable, Hashable, Identifiable, Sendable {
    let reward: Reward
    let qty: Int
    let claimedAt: Date
    var id: String { reward.id }
}

struct Dashboard: Codable, Sendable {
    struct RegionRef: Codable, Sendable { let id: String; let slug: String; let name: String }
    struct Stats: Codable, Sendable { let checkinsTotal: Int; let checkinsThisWeek: Int; let uniqueSpots: Int; let friends: Int }
    struct OnlineFriend: Codable, Hashable, Identifiable, Sendable {
        let user: PublicUser
        let lastSeenAt: Date
        let distanceMeters: Double?
        var id: String { user.id }
    }
    struct FriendsOnline: Codable, Sendable { let count: Int; let total: Int; let users: [OnlineFriend] }
    struct Rank: Codable, Sendable { let period: String; let rank: Int?; let score: Int; let top: [Leaderboard.Entry] }

    let user: Me
    let position: LatLng?
    let region: RegionRef?
    let stats: Stats
    let nearbySpots: [Spot]
    let quests: [Quest]
    let friendsOnline: FriendsOnline
    let leaderboard: Rank
    let events: [GameEvent]
}

struct Health: Codable, Sendable {
    struct Database: Codable, Sendable { let state: String; let latencyMs: Int? }
    let status: String
    let version: String
    let environment: String
    let database: Database
}
