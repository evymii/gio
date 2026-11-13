import SwiftUI

/// Big-number rankings, this week or all time, campus-wide or per region.
struct LeaderboardView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var period = "weekly"
    @State private var region: String?
    @State private var regions: [Region] = []
    @State private var board: Leaderboard?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                StackedTitle(primary: "Leader", secondary: "board", size: 48).appear()
                HStack(spacing: 4) {
                    Chip(title: "This week", selected: period == "weekly") { period = "weekly" }
                    Chip(title: "All time", selected: period == "all_time") { period = "all_time" }
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        regionChip(nil, "Whole campus", Theme.Colors.yellow)
                        ForEach(Array(regions.enumerated()), id: \.element.id) { i, r in regionChip(r.slug, r.name, Theme.Colors.cycled(i)) }
                    }
                }

                if let board {
                    if let me = board.me.rank {
                        Card(color: Theme.Colors.yellow) {
                            HStack(alignment: .lastTextBaseline) {
                                StackedTitle(primary: "You", secondary: "\(board.me.score) XP", size: 28,
                                             primaryColor: Theme.Colors.ink, secondaryColor: Theme.Colors.ink.opacity(0.5))
                                Spacer()
                                Text("#\(me)").font(Theme.Fonts.number(72, weight: .regular)).tracking(-3).foregroundStyle(Theme.Colors.ink)
                            }
                        }
                        .appear()
                    }
                    if board.entries.isEmpty {
                        Card { Text("No XP earned here yet.").font(Theme.Fonts.body).foregroundStyle(Theme.Colors.textSecondary) }
                    }
                    VStack(spacing: 0) {
                        ForEach(Array(board.entries.enumerated()), id: \.element.id) { i, e in
                            row(e).appear(delay: Double(i) * 0.03)
                        }
                    }
                } else {
                    ProgressView().tint(Theme.Colors.yellow).frame(maxWidth: .infinity).padding(.top, 40)
                }
            }
            .padding(Theme.Spacing.m)
        }
        .pageBackground()
        .navigationBarTitleDisplayMode(.inline)
        .task { regions = (try? await env.api.regions()) ?? [] }
        .task(id: "\(period)|\(region ?? "")") { await load() }
        .refreshable { await load() }
    }

    private func row(_ e: Leaderboard.Entry) -> some View {
        HStack(spacing: 14) {
            Text("\(e.rank)").font(Theme.Fonts.number(44, weight: e.rank <= 3 ? .bold : .regular)).tracking(-2)
                .foregroundStyle(e.rank <= 3 ? Theme.Colors.yellow : Theme.Colors.text)
                .frame(width: 62, alignment: .leading)
            VStack(alignment: .leading, spacing: -2) {
                Text(e.user.name).font(Theme.Fonts.display(24)).tracking(-0.6)
                Text(e.isMe ? "You · level \(e.user.level)" : "Level \(e.user.level)").font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
            }
            Spacer()
            Text("\(e.score)").font(Theme.Fonts.bold(18)).monospacedDigit()
            AvatarView(avatar: e.user.avatar, name: e.user.name, size: 44)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, e.isMe ? 12 : 0)
        .background(e.isMe ? Theme.Colors.surface : .clear, in: RoundedRectangle(cornerRadius: 20))
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.Colors.line).frame(height: 1).opacity(e.isMe ? 0 : 1) }
        .accessibilityElement(children: .combine)
    }

    private func regionChip(_ slug: String?, _ name: String, _ color: Color) -> some View {
        Button { region = slug } label: {
            HStack(spacing: 8) {
                Circle().fill(color).frame(width: 12, height: 12)
                Text(name).font(Theme.Fonts.bold(14))
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .foregroundStyle(region == slug ? Theme.Colors.ink : Theme.Colors.text)
            .background(region == slug ? Color.white : Theme.Colors.surface, in: Capsule())
        }
        .buttonStyle(PressableStyle())
    }

    private func load() async {
        withAnimation { board = nil }
        let b = try? await env.api.leaderboard(period: period, region: region)
        withAnimation(.spring(response: 0.4)) { board = b }
    }
}
