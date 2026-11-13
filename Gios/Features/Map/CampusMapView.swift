import MapKit
import SwiftUI

/// Live campus map: spots (with check-in radius), friends sharing their location, and you.
struct CampusMapView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var spots: [Spot] = []
    @State private var friends: [FriendLocation] = []
    @State private var selected: Spot?
    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var error: String?

    var body: some View {
        Map(position: $position) {
            UserAnnotation()
            ForEach(spots) { spot in
                MapCircle(center: spot.coordinate, radius: spot.radiusMeters)
                    .foregroundStyle(Theme.spotStyle(spot.type).color.opacity(0.12))
                    .stroke(Theme.spotStyle(spot.type).color.opacity(0.5), lineWidth: 1)
                Annotation(spot.name, coordinate: spot.coordinate) {
                    Button { selected = spot } label: {
                        SpotIcon(type: spot.type, size: 34)
                            .overlay(alignment: .topTrailing) {
                                if spot.isOnCooldown {
                                    Image(systemName: "checkmark.circle.fill").font(.caption)
                                        .foregroundStyle(.white, Theme.Colors.online).offset(x: 5, y: -5)
                                }
                            }
                            .shadow(radius: 3, y: 2)
                    }
                    .accessibilityLabel("\(spot.name), \(spot.rewardXp) XP")
                }
            }
            ForEach(friends) { f in
                Annotation(f.user.name, coordinate: f.coordinate) {
                    AvatarView(avatar: f.user.avatar, name: f.user.name, size: 38, online: f.online)
                        .overlay(Circle().stroke(.white, lineWidth: 3))
                        .shadow(radius: 3, y: 2)
                }
            }
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
        .navigationTitle("Map")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { Task { await load() } } label: { Image(systemName: "arrow.clockwise") }
                    .accessibilityLabel("Refresh map")
            }
        }
        .safeAreaInset(edge: .bottom) { legend }
        .sheet(item: $selected) { spot in
            SpotSheet(spot: spot) { Task { await load() } }
                .presentationDetents([.height(320), .medium])
        }
        .task {
            // Refresh friends + spots every 30 s while the map is on screen.
            while !Task.isCancelled {
                await load()
                try? await Task.sleep(for: .seconds(30))
            }
        }
        .onChange(of: env.location.location == nil) { _, isNil in if !isNil { Task { await load() } } }
        .alert("Couldn't load the map", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(error ?? "") }
    }

    private var onlineCount: Int { friends.filter(\.online).count }

    private var legend: some View {
        HStack(spacing: Theme.Spacing.m) {
            Label("\(spots.count) spots", systemImage: "mappin.circle.fill")
            Label(onlineCount == 1 ? "1 friend online" : "\(onlineCount) friends online", systemImage: "person.2.fill")
        }
        .font(Theme.Fonts.caption.weight(.semibold))
        .padding(.horizontal, Theme.Spacing.m).padding(.vertical, 10)
        .background(.regularMaterial, in: Capsule())
        .padding(.bottom, Theme.Spacing.s)
    }

    private func load() async {
        // Without a GPS fix yet, centre the query on the campus via the dashboard's last known position.
        let center = env.location.location?.coordinate
        do {
            async let f = env.api.friendLocations()
            if let center {
                spots = try await env.api.nearbySpots(at: center, radius: 3000)
            } else if let pos = try await env.api.dashboard(at: nil).position {
                spots = try await env.api.nearbySpots(at: pos.coordinate, radius: 3000)
                position = .region(MKCoordinateRegion(center: pos.coordinate, latitudinalMeters: 1200, longitudinalMeters: 1200))
            }
            friends = try await f
        } catch APIError.sessionExpired {
        } catch {
            self.error = error.localizedDescription
        }
    }
}

/// Bottom sheet for one spot: details + check-in.
struct SpotSheet: View {
    let spot: Spot
    var onChange: () -> Void
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @State private var working = false
    @State private var result: String?

    private var distance: Double? {
        env.location.location.map { $0.distance(from: CLLocation(latitude: spot.lat, longitude: spot.lng)) } ?? spot.distanceMeters
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack(spacing: Theme.Spacing.m) {
                SpotIcon(type: spot.type, size: 52)
                VStack(alignment: .leading, spacing: 2) {
                    Text(spot.name).font(Theme.Fonts.title)
                    Text("\(spot.type.capitalized) · \(formatDistance(distance)) away")
                        .font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
                }
            }
            if !spot.description.isEmpty { Text(spot.description).font(Theme.Fonts.body) }
            HStack(spacing: Theme.Spacing.l) {
                Label("+\(spot.rewardXp) XP", systemImage: "star.fill").foregroundStyle(Theme.Colors.xp)
                Label("\(Int(spot.radiusMeters)) m radius", systemImage: "scope").foregroundStyle(Theme.Colors.textSecondary)
            }
            .font(Theme.Fonts.caption.weight(.semibold))

            if let result {
                Text(result).font(Theme.Fonts.body).padding(Theme.Spacing.s + 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.Colors.accentSoft, in: RoundedRectangle(cornerRadius: Theme.Radius.control))
            }
            Spacer(minLength: 0)
            Button {
                Task { await checkIn() }
            } label: {
                if working { ProgressView().tint(.white) }
                else { Text(spot.isOnCooldown ? "Checked in recently" : "Check in") }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(working || spot.isOnCooldown)
        }
        .padding(Theme.Spacing.l)
    }

    private func checkIn() async {
        working = true
        defer { working = false }
        do {
            result = summary(of: try await env.checkIn(spot))
            onChange()
        } catch {
            result = error.localizedDescription
        }
    }
}
