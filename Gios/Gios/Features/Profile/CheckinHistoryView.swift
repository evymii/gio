import SwiftUI

/// Streak + total, dot calendars for this and last month, and the list.
struct CheckinHistoryView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var items: [CheckinHistoryItem]?
    @State private var error: String?

    private var counts: [Date: Int] {
        Dictionary(grouping: items ?? []) { Calendar.current.startOfDay(for: $0.createdAt) }.mapValues(\.count)
    }

    /// Consecutive days with a check-in, ending today (or yesterday).
    private var streak: Int {
        let cal = Calendar.current
        var day = cal.startOfDay(for: .now)
        if counts[day] == nil { day = cal.date(byAdding: .day, value: -1, to: day)! }
        var n = 0
        while counts[day] != nil { n += 1; day = cal.date(byAdding: .day, value: -1, to: day)! }
        return n
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 20) {
                    HStack(spacing: 6) { Text("Streak").foregroundStyle(Theme.Colors.textSecondary); Text("\(streak)") }
                    HStack(spacing: 6) { Text("Total").foregroundStyle(Theme.Colors.textSecondary); Text("\(items?.count ?? 0)") }
                    Spacer()
                }
                .font(Theme.Fonts.bold(22))
                .appear()

                Card { DotCalendar(month: .now, counts: counts) }.appear(delay: 0.05)
                if let last = Calendar.current.date(byAdding: .month, value: -1, to: .now) {
                    Card { DotCalendar(month: last, counts: counts, color: Theme.Colors.lavender) }.appear(delay: 0.1)
                }

                if let items {
                    SectionHeader("Recent", subtitle: "\(items.count) check-ins")
                    if items.isEmpty {
                        Card { Text("Walk to a spot and check in to start your streak.").font(Theme.Fonts.body).foregroundStyle(Theme.Colors.textSecondary) }
                    } else {
                        CardStack(items: Array(items.prefix(12))) { _, c in
                            let style = Theme.spotStyle(c.spot.type)
                            StackCard(color: style.color, title: c.spot.name,
                                      subtitle: c.createdAt.formatted(.dateTime.weekday(.wide).hour().minute()),
                                      value: "+\(c.xpAwarded)", unit: "XP", arrow: "checkmark") {
                                LineBadge(icon: style.icon, color: Theme.foreground(on: style.color).opacity(0.1), size: 40,
                                          foreground: Theme.foreground(on: style.color))
                            }
                        }
                    }
                } else {
                    ProgressView().tint(Theme.Colors.yellow).frame(maxWidth: .infinity)
                }
            }
            .padding(Theme.Spacing.m)
        }
        .pageBackground()
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
        .errorAlert(message: $error)
    }

    private func load() async {
        do { items = try await env.api.checkinHistory(limit: 100) }
        catch APIError.sessionExpired {}
        catch { self.error = error.localizedDescription }
    }
}
