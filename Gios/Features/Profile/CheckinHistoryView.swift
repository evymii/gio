import SwiftUI

/// Your verified check-ins, grouped by day.
struct CheckinHistoryView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var items: [CheckinHistoryItem]?
    @State private var error: String?

    private var days: [(day: Date, items: [CheckinHistoryItem])] {
        let groups = Dictionary(grouping: items ?? []) { Calendar.current.startOfDay(for: $0.createdAt) }
        return groups.keys.sorted(by: >).map { ($0, groups[$0]!.sorted { $0.createdAt > $1.createdAt }) }
    }

    var body: some View {
        List {
            if let items {
                if items.isEmpty {
                    ContentUnavailableView("No check-ins yet", systemImage: "mappin.slash",
                                           description: Text("Walk to a spot on the map and check in to earn XP."))
                }
                ForEach(days, id: \.day) { group in
                    Section(group.day.formatted(.relative(presentation: .named, unitsStyle: .wide)).capitalized) {
                        ForEach(group.items) { c in
                            HStack(spacing: Theme.Spacing.s + 4) {
                                SpotIcon(type: c.spot.type, size: 34)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(c.spot.name).font(Theme.Fonts.body.weight(.semibold))
                                    Text(c.createdAt.formatted(date: .omitted, time: .shortened))
                                        .font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
                                }
                                Spacer()
                                Text("+\(c.xpAwarded) XP").font(Theme.Fonts.caption.weight(.bold)).foregroundStyle(Theme.Colors.xp)
                            }
                        }
                    }
                }
            } else {
                ProgressView().frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Check-ins")
        .task { await load() }
        .refreshable { await load() }
        .errorAlert(message: $error)
    }

    private func load() async {
        do { items = try await env.api.checkinHistory() }
        catch APIError.sessionExpired {}
        catch { self.error = error.localizedDescription }
    }
}
