import CoreLocation
import Foundation

/// Uploads your position for friends while sharing is on — throttled so the
/// battery and server aren't hammered: at most every 30 s, or sooner after
/// moving 25 m. Failed points are kept and retried with the next upload.
@MainActor
final class LocationSharer {
    private let api: APIClient
    private var pending: [CLLocation] = []
    private var lastSent: CLLocation?
    private var lastSentAt: Date = .distantPast
    private var uploading = false
    var isEnabled = false

    static let minInterval: TimeInterval = 30
    static let minDistance: CLLocationDistance = 25

    init(api: APIClient) { self.api = api }

    func handle(_ location: CLLocation) {
        guard isEnabled else { return }
        pending.append(location)
        if pending.count > 50 { pending.removeFirst(pending.count - 50) }
        let moved = lastSent.map { location.distance(from: $0) } ?? .infinity
        let due = Date().timeIntervalSince(lastSentAt) >= Self.minInterval || moved >= Self.minDistance
        if due { flush() }
    }

    func flush() {
        guard !uploading, !pending.isEmpty else { return }
        uploading = true
        let batch = pending
        Task {
            defer { uploading = false }
            do {
                try await api.uploadLocations(batch)
                pending.removeFirst(min(batch.count, pending.count))
                lastSent = batch.last
                lastSentAt = Date()
            } catch {
                // Keep points; next fix retries.
            }
        }
    }
}
