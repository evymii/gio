import CoreLocation
import SwiftUI

/// Campus guide: a badge grid to filter by type, then stacked spot cards (nearest first).
struct SpotsListView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var spots: [Spot]?
    @State private var type: String?
    @State private var selected: Spot?
    @State private var error: String?

    private static let types = ["library", "cafe", "study", "sports", "landmark", "food", "event"]

    private func distance(_ s: Spot) -> Double? {
        env.location.location?.distance(from: CLLocation(latitude: s.lat, longitude: s.lng))
    }
    private var sorted: [Spot] {
        (spots ?? []).sorted { (distance($0) ?? .infinity, $0.name) < (distance($1) ?? .infinity, $1.name) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                StackedTitle(primary: "Campus", secondary: "Guide", size: 44).appear()
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 14) {
                    filterBadge(nil, icon: "square.grid.2x2.fill", color: .white, label: "All")
                    ForEach(Self.types, id: \.self) { t in
                        let s = Theme.spotStyle(t)
                        filterBadge(t, icon: s.icon, color: s.color, label: t.capitalized)
                    }
                }
                .appear(delay: 0.05)

                if spots != nil {
                    SectionHeader(type?.capitalized ?? "All spots", subtitle: "\(sorted.count) places")
                    if sorted.isEmpty {
                        Card { Text("No spots of this type yet.").font(Theme.Fonts.body).foregroundStyle(Theme.Colors.textSecondary) }
                    }
                    CardStack(items: sorted) { _, s in
                        Button { selected = s } label: { SpotCard(spot: s, distance: distance(s)) }
                            .buttonStyle(PressableStyle())
                    }
                    .id(type) // re-run the stagger when the filter changes
                } else {
                    ProgressView().tint(Theme.Colors.yellow).frame(maxWidth: .infinity)
                }
            }
            .padding(Theme.Spacing.m)
        }
        .pageBackground()
        .navigationBarTitleDisplayMode(.inline)
        .task(id: type) { await load() }
        .refreshable { await load() }
        .sheet(item: $selected) { spot in SpotSheet(spot: spot) { Task { await load() } } }
        .errorAlert(message: $error)
    }

    private func filterBadge(_ value: String?, icon: String, color: Color, label: String) -> some View {
        Button { withAnimation(.spring(response: 0.35)) { type = value } } label: {
            VStack(spacing: 6) {
                LineBadge(icon: icon, color: color, size: 64)
                    .overlay(Circle().strokeBorder(.white, lineWidth: type == value ? 3 : 0).padding(-5))
                    .scaleEffect(type == value ? 0.92 : 1)
                    .opacity(type == nil || type == value ? 1 : 0.45)
                Text(label).font(Theme.Fonts.micro).foregroundStyle(type == value ? Theme.Colors.text : Theme.Colors.textSecondary)
            }
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(label)
        .accessibilityAddTraits(type == value ? .isSelected : [])
    }

    private func load() async {
        do { spots = try await env.api.allSpots(type: type) }
        catch APIError.sessionExpired {}
        catch { self.error = error.localizedDescription }
    }
}
