import Foundation

enum CheckinError: LocalizedError {
    case noLocation
    var errorDescription: String? { "We don't know where you are yet. Allow location access and try again." }
}

extension AppEnvironment {
    /// Check in at a spot using the current GPS fix. Refreshes your XP afterwards.
    func checkIn(_ spot: Spot) async throws -> CheckinResult {
        guard let here = location.location else { throw CheckinError.noLocation }
        let result = try await api.checkIn(spotId: spot.id, at: here)
        if result.checkin.verified { await session.refreshMe() }
        return result
    }

    func claim(_ quest: Quest) async throws -> ClaimResult {
        let result = try await api.claimQuest(quest.id)
        await session.refreshMe()
        return result
    }
}

/// Short text for a check-in outcome, including quests it advanced.
func summary(of r: CheckinResult) -> String {
    var lines = [r.message]
    if r.user?.leveledUp == true, let level = r.user?.level { lines.append("Level up! You're now level \(level).") }
    for q in r.quests where q.completed { lines.append("Quest complete: \(q.title) — claim it on Home.") }
    return lines.joined(separator: "\n")
}
