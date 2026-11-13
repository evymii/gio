import SwiftUI

/// Campus-wide XP ranking, this week or all time.
struct LeaderboardView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var period = "weekly"
    @State private var region: String? // nil = whole campus
    @State private var regions: [Region] = []
    @State private var board: Leaderboard?

    var body: some View {
        List {
            Section {
                Picker("Period", selection: $period) {
                    Text("This week").tag("weekly")
                    Text("All time").tag("all_time")
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
            }
            if let board {
                Section {
                    if board.entries.isEmpty { Text("No XP earned yet.").foregroundStyle(Theme.Colors.textSecondary) }
                    ForEach(board.entries) { e in
                        HStack(spacing: Theme.Spacing.s + 4) {
                            Text("\(e.rank)").font(Theme.Fonts.headline.monospacedDigit()).frame(width: 28)
                                .foregroundStyle(e.rank <= 3 ? Theme.Colors.xp : Theme.Colors.textSecondary)
                            AvatarView(avatar: e.user.avatar, name: e.user.name, size: 36)
                            Text(e.isMe ? "\(e.user.name) (you)" : e.user.name).font(Theme.Fonts.body.weight(e.isMe ? .bold : .regular))
                            Spacer()
                            Text("\(e.score) XP").font(Theme.Fonts.caption.weight(.semibold).monospacedDigit())
                        }
                        .listRowBackground(e.isMe ? Theme.Colors.accentSoft : nil)
                    }
                } footer: {
                    Text(board.me.rank.map { "You're #\($0) with \(board.me.score) XP." } ?? "Check in at a spot to get ranked.")
                }
            } else {
                ProgressView().frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Leaderboard")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Area", selection: $region) {
                        Text("Whole campus").tag(String?.none)
                        ForEach(regions) { Text($0.name).tag(String?.some($0.slug)) }
                    }
                } label: {
                    Label(regions.first { $0.slug == region }?.name ?? "Whole campus", systemImage: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .task { regions = (try? await env.api.regions()) ?? [] }
        .task(id: "\(period)|\(region ?? "")") { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        board = nil
        board = try? await env.api.leaderboard(period: period, region: region)
    }
}
