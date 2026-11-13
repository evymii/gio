import CoreLocation
import SwiftUI

/// Every spot on campus, filterable by type, nearest first. Tap to check in.
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
        List {
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.s) {
                        chip(nil, "All")
                        ForEach(Self.types, id: \.self) { chip($0, $0.capitalized) }
                    }
                    .padding(.vertical, 2)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
            }
            if spots != nil {
                Section("\(sorted.count) spots") {
                    ForEach(sorted) { s in
                        Button { selected = s } label: {
                            HStack(spacing: Theme.Spacing.s + 4) {
                                SpotIcon(type: s.type)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(s.name).font(Theme.Fonts.body.weight(.semibold)).foregroundStyle(Theme.Colors.text)
                                    Text([formatDistance(distance(s)), "+\(s.rewardXp) XP"].filter { !$0.isEmpty }.joined(separator: " · "))
                                        .font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.Colors.textSecondary)
                            }
                        }
                    }
                }
            } else {
                ProgressView().frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Spots")
        .task(id: type) { await load() }
        .refreshable { await load() }
        .sheet(item: $selected) { spot in
            SpotSheet(spot: spot) { Task { await load() } }
                .presentationDetents([.height(320), .medium])
        }
        .errorAlert(message: $error)
    }

    private func chip(_ value: String?, _ label: String) -> some View {
        Button { type = value } label: {
            Text(label).font(Theme.Fonts.caption.weight(.semibold))
                .padding(.horizontal, 12).padding(.vertical, 7)
                .foregroundStyle(type == value ? .white : Theme.Colors.text)
                .background(type == value ? Theme.Colors.accent : Theme.Colors.surface, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func load() async {
        do { spots = try await env.api.allSpots(type: type) }
        catch APIError.sessionExpired {}
        catch { self.error = error.localizedDescription }
    }
}
