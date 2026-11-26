import CoreLocation
import Foundation
import Observation

/// Wraps CLLocationManager: permission, live position, and a hook for sharing.
@MainActor
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private(set) var authorization: CLAuthorizationStatus
    private(set) var location: CLLocation?
    /// Called for every new fix (used by the sharing uploader).
    @ObservationIgnored var onUpdate: ((CLLocation) -> Void)?

    override init() {
        authorization = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = 10
    }

    var isAuthorized: Bool { authorization == .authorizedWhenInUse || authorization == .authorizedAlways }
    var isDenied: Bool { authorization == .denied || authorization == .restricted }

    func requestPermission() {
        if authorization == .notDetermined { manager.requestWhenInUseAuthorization() }
    }

    func start() {
        if isAuthorized { manager.startUpdatingLocation() } else { requestPermission() }
    }

    func stop() { manager.stopUpdatingLocation() }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorization = status
            if self.isAuthorized { self.manager.startUpdatingLocation() }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last, last.horizontalAccuracy >= 0 else { return }
        Task { @MainActor in
            self.location = last
            self.onUpdate?(last)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}
