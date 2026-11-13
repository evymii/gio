import MapKit
import SwiftUI

/// Live campus map: region lines, spots (signage pins + radius), friends, and you.
struct CampusMapView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var spots: [Spot] = []
    @State private var friends: [FriendLocation] = []
    @State private var regions: [Region] = []
    @State private var selected: Spot?
    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var error: String?

    private var onlineCount: Int { friends.filter(\.online).count }

    var body: some View {
        Map(position: $position) {
            ForEach(Array(regions.enumerated()), id: \.element.id) { i, r in
                MapPolygon(coordinates: r.boundary.map(\.coordinate))
                    .foregroundStyle(Theme.Colors.cycled(i).opacity(0.06))
                    .stroke(Theme.Colors.cycled(i), style: StrokeStyle(lineWidth: 3, dash: [10, 6]))
            }
            UserAnnotation()
            ForEach(spots) { spot in
                let style = Theme.spotStyle(spot.type)
                MapCircle(center: spot.coordinate, radius: spot.radiusMeters)
                    .foregroundStyle(style.color.opacity(0.18))
                    .stroke(style.color, lineWidth: 1.5)
                Annotation(spot.name, coordinate: spot.coordinate, anchor: .center) {
                    Button { selected = spot } label: {
                        SpotIcon(type: spot.type, size: 40)
                            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).stroke(.black, lineWidth: 3))
                            .overlay(alignment: .topTrailing) {
                                if spot.isOnCooldown {
                                    LineBadge(icon: "checkmark", color: Theme.Colors.green, size: 18).offset(x: 6, y: -6)
                                }
                            }
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel("\(spot.name), \(spot.rewardXp) XP")
                }
            }
            ForEach(friends) { f in
                Annotation(f.user.name, coordinate: f.coordinate, anchor: .center) {
                    AvatarView(avatar: f.user.avatar, name: f.user.name, size: 40, online: f.online)
                        .overlay(Circle().stroke(.black, lineWidth: 3))
                }
            }
        }
        .mapStyle(.standard(emphasis: .muted, pointsOfInterest: .excludingAll))
        .mapControls { MapCompass() }
        .ignoresSafeArea(edges: .top)
        .overlay(alignment: .top) { header }
        .overlay(alignment: .bottomTrailing) {
            VStack(spacing: 10) {
                NavigationLink { SpotsListView() } label: {
                    Image(systemName: "list.bullet").font(.system(size: 18, weight: .bold)).frame(width: 52, height: 52)
                        .foregroundStyle(Theme.Colors.text).background(.black, in: Circle())
                }
                .accessibilityLabel("All spots")
                CircleButton(systemName: "location.fill", size: 52, fill: Theme.Colors.yellow) {
                    withAnimation(.spring) { position = .userLocation(fallback: .automatic) }
                }
                .accessibilityLabel("My location")
            }
            .padding(Theme.Spacing.m)
            .padding(.bottom, 84) // clear the floating tab bar
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $selected) { spot in SpotSheet(spot: spot) { Task { await load() } } }
        .task { regions = (try? await env.api.regions()) ?? [] }
        .task {
            while !Task.isCancelled {
                await load()
                try? await Task.sleep(for: .seconds(30))
            }
        }
        .onChange(of: env.location.location == nil) { _, isNil in if !isNil { Task { await load() } } }
        .errorAlert("Couldn't load the map", message: $error)
    }

    private var header: some View {
        HStack(alignment: .top) {
            StackedTitle(primary: "Campus", secondary: "Live map", size: 32)
            Spacer()
            HStack(spacing: 6) {
                LineBadge("\(spots.count)", color: Theme.Colors.lavender, size: 38)
                LineBadge("\(onlineCount)", color: Theme.Colors.green, size: 38)
                Button { Task { await load() } } label: { ArrowBadge(systemName: "arrow.clockwise", color: .white, foreground: Theme.Colors.ink, size: 38) }
                    .accessibilityLabel("Refresh")
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("\(spots.count) spots, \(onlineCount) friends online")
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.top, 60)
        .padding(.bottom, 26)
        .background(LinearGradient(colors: [.black, .black.opacity(0.85), .clear], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
    }

    private func load() async {
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

/// White card for one spot: big name, proximity bar, ✕ / ✓ actions.
struct SpotSheet: View {
    let spot: Spot
    var onChange: () -> Void
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @State private var working = false
    @State private var result: CheckinResult?
    @State private var error: String?

    private var distance: Double? {
        env.location.location.map { $0.distance(from: CLLocation(latitude: spot.lat, longitude: spot.lng)) } ?? spot.distanceMeters
    }
    private var inRange: Bool { (distance ?? .infinity) <= spot.radiusMeters + 50 }
    /// 1 when inside the radius, falling to 0 at 1 km beyond it.
    private var proximity: Double {
        guard let d = distance else { return 0 }
        return d <= spot.radiusMeters ? 1 : max(0.05, 1 - (d - spot.radiusMeters) / 1000)
    }
    private var done: Bool { spot.isOnCooldown || result?.checkin.verified == true }

    var body: some View {
        let style = Theme.spotStyle(spot.type)
        VStack(spacing: 0) {
            HStack {
                Circle().strokeBorder(Theme.Colors.ink.opacity(0.15), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                    .frame(width: 52, height: 52)
                    .overlay(Image(systemName: style.icon).font(.system(size: 20, weight: .bold)))
                Spacer()
                Text(spot.type.capitalized).font(Theme.Fonts.micro)
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .overlay(Capsule().strokeBorder(Theme.Colors.ink.opacity(0.15)))
                Spacer()
                Circle().strokeBorder(Theme.Colors.ink.opacity(0.15), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                    .frame(width: 52, height: 52)
                    .overlay(Text("+\(spot.rewardXp)").font(Theme.Fonts.bold(14)))
                    .accessibilityLabel("\(spot.rewardXp) XP")
            }
            .padding(.horizontal, 20).padding(.top, 20)

            Spacer(minLength: 16)
            Text(spot.name).font(.system(size: 44, weight: .medium)).tracking(-1.5)
                .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.6)
                .padding(.horizontal, 24)
            if !spot.description.isEmpty {
                Text(spot.description).font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.ink.opacity(0.45))
                    .multilineTextAlignment(.center).padding(.horizontal, 32).padding(.top, 6)
            }
            Spacer(minLength: 16)

            SegmentBar(fraction: done ? 1 : proximity, color: done ? Theme.Colors.green : style.color == Theme.Colors.yellow ? Theme.Colors.orange : style.color)
                .padding(.horizontal, 12)
            VStack(spacing: 2) {
                Text(statusTitle).font(.system(size: 24, weight: .medium))
                Text(statusSubtitle).font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.ink.opacity(0.4))
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 18)
            .padding(.horizontal, 24)
            .animation(.spring, value: result?.checkin.id)

            HStack {
                CircleButton(systemName: "xmark", size: 60, foreground: Theme.Colors.ink) { dismiss() }
                    .overlay(Circle().strokeBorder(Theme.Colors.ink.opacity(0.12), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3])))
                    .accessibilityLabel("Close")
                Spacer()
                VStack(spacing: 2) {
                    Text(formatDistance(distance)).font(Theme.Fonts.bold(18))
                    Text("\(Int(spot.radiusMeters)) m radius").font(Theme.Fonts.micro).foregroundStyle(Theme.Colors.ink.opacity(0.4))
                }
                Spacer()
                Button { Task { await checkIn() } } label: {
                    ZStack {
                        Circle().fill(done ? Theme.Colors.green : (inRange ? Theme.Colors.ink : Theme.Colors.ink.opacity(0.08)))
                        if working { ProgressView().tint(.white) }
                        else { Image(systemName: "checkmark").font(.system(size: 22, weight: .heavy)).foregroundStyle(done || inRange ? .white : Theme.Colors.ink.opacity(0.3)) }
                    }
                    .frame(width: 60, height: 60)
                }
                .buttonStyle(PressableStyle())
                .disabled(working || done)
                .accessibilityLabel(done ? "Checked in" : "Check in")
            }
            .padding(.horizontal, 20).padding(.bottom, 20)
        }
        .foregroundStyle(Theme.Colors.ink)
        .background(Theme.Colors.paper)
        .presentationDetents([.height(520)])
        .presentationCornerRadius(40)
        .presentationBackground(Theme.Colors.paper)
        .sensoryFeedback(.success, trigger: result?.checkin.verified == true)
        .errorAlert("Check-in failed", message: $error)
    }

    private var statusTitle: String {
        if let result { return result.checkin.verified ? "+\(result.checkin.xpAwarded) XP" : "Get closer" }
        if spot.isOnCooldown { return "Checked in" }
        return inRange ? "You're here" : "On your way"
    }

    private var statusSubtitle: String {
        if let result { return summary(of: result) }
        if spot.isOnCooldown, let until = spot.cooldownUntil { return "Again \(until.formatted(.relative(presentation: .named)))" }
        return inRange ? "Tap ✓ to check in" : "Walk into the circle to check in"
    }

    private func checkIn() async {
        working = true
        defer { working = false }
        do {
            result = try await env.checkIn(spot)
            onChange()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
