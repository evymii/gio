import CoreLocation
import Foundation
import Observation

@MainActor
@Observable
final class DashboardViewModel {
    enum State { case loading, loaded(Dashboard), failed(String) }
    private(set) var state: State = .loading
    private(set) var busySpotId: String?
    private(set) var busyQuestId: String?
    var toast: String?

    func load(_ env: AppEnvironment) async {
        if case .loaded = state {} else { state = .loading }
        do {
            state = .loaded(try await env.api.dashboard(at: env.location.location?.coordinate))
        } catch APIError.sessionExpired {
            // RootView switches to login.
        } catch {
            if case .loaded = state { toast = error.localizedDescription } else { state = .failed(error.localizedDescription) }
        }
    }

    func checkIn(_ spot: Spot, env: AppEnvironment) async {
        busySpotId = spot.id
        defer { busySpotId = nil }
        do {
            toast = summary(of: try await env.checkIn(spot))
            await load(env)
        } catch {
            toast = error.localizedDescription
        }
    }

    func claim(_ quest: Quest, env: AppEnvironment) async {
        busyQuestId = quest.id
        defer { busyQuestId = nil }
        do {
            let r = try await env.claim(quest)
            toast = "+\(r.xpAwarded) XP" + (r.reward.map { " · \($0.name) added to your inventory" } ?? "")
            await load(env)
        } catch {
            toast = error.localizedDescription
        }
    }
}
