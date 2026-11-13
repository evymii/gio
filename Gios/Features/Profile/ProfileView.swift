import SwiftUI

/// You: big numbers, sharing / ghost mode, check-in calendar, rewards, links, log out.
struct ProfileView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var inventory: [InventoryEntry] = []
    @State private var history: [CheckinHistoryItem] = []
    @State private var health: Health?
    @State private var savingSharing = false
    @State private var confirmLogout = false
    @State private var error: String?

    private var counts: [Date: Int] {
        Dictionary(grouping: history) { Calendar.current.startOfDay(for: $0.createdAt) }.mapValues(\.count)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                if let me = env.session.me {
                    header(me).appear()
                    numbers(me).appear(delay: 0.05)
                    sharing(me).appear(delay: 0.1)
                }
                Card { DotCalendar(month: .now, counts: counts) }.appear(delay: 0.15)
                rewards
                links
                server
                Button("Log out") { confirmLogout = true }
                    .buttonStyle(PillButtonStyle(fill: Theme.Colors.red))
            }
            .padding(Theme.Spacing.m)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .scrollIndicators(.hidden)
        .pageBackground()
        .toolbar(.hidden, for: .navigationBar)
        .task { await load() }
        .refreshable { await load() }
        .confirmationDialog("Log out of Gios?", isPresented: $confirmLogout, titleVisibility: .visible) {
            Button("Log out", role: .destructive) { Task { await env.signOut() } }
        }
        .errorAlert("Couldn't update", message: $error)
    }

    private func header(_ me: Me) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 14) {
                AvatarView(avatar: me.avatar, name: me.name, size: 84)
                StackedTitle(primary: me.name, secondary: me.email, size: 34)
            }
            Spacer()
            NavigationLink { EditProfileView() } label: {
                ArrowBadge(systemName: "pencil", color: .white, foreground: Theme.Colors.ink, size: 48)
            }
            .accessibilityLabel("Edit profile")
        }
    }

    private func numbers(_ me: Me) -> some View {
        HStack(alignment: .lastTextBaseline) {
            BigStat(value: "\(me.level)", unit: "Level", size: 64)
            Spacer()
            BigStat(value: "\(history.count)", unit: "Check-ins", size: 64)
            Spacer()
            BigStat(value: "\(me.xp)", unit: "XP", size: 64)
        }
    }

    private func sharing(_ me: Me) -> some View {
        Button { Task { await setSharing(!me.isSharing) } } label: {
            HStack(spacing: 14) {
                LineBadge(icon: me.isSharing ? "location.fill" : "eye.slash.fill",
                          color: me.isSharing ? Theme.Colors.ink : Theme.Colors.surface2, size: 52,
                          foreground: me.isSharing ? Theme.Colors.green : Theme.Colors.text)
                VStack(alignment: .leading, spacing: 0) {
                    Text(me.isSharing ? "Visible" : "Ghost mode").font(Theme.Fonts.display(26)).tracking(-0.8)
                    Text(me.isSharing ? "Friends see you on the map" : "No one can see where you are")
                        .font(Theme.Fonts.caption).opacity(0.65)
                }
                Spacer()
                if savingSharing { ProgressView() } else {
                    Capsule().fill(me.isSharing ? Theme.Colors.ink : Theme.Colors.surface2)
                        .frame(width: 58, height: 34)
                        .overlay(alignment: me.isSharing ? .trailing : .leading) {
                            Circle().fill(me.isSharing ? Theme.Colors.green : Theme.Colors.textSecondary).padding(4)
                        }
                }
            }
            .foregroundStyle(me.isSharing ? Theme.Colors.ink : Theme.Colors.text)
            .padding(14).padding(.trailing, 6)
            .background(me.isSharing ? Theme.Colors.green : Theme.Colors.surface, in: Capsule())
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: me.isSharing)
        }
        .buttonStyle(PressableStyle())
        .disabled(savingSharing)
        .sensoryFeedback(.impact, trigger: me.isSharing)
        .accessibilityLabel(me.isSharing ? "Location sharing on" : "Ghost mode on")
        .accessibilityHint("Double tap to toggle")
    }

    private var rewards: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Rewards", subtitle: "\(inventory.count) earned") { NavigationLink("See all") { RewardsView() } }
            if inventory.isEmpty {
                Card { Text("Complete quests to earn badges.").font(Theme.Fonts.body).foregroundStyle(Theme.Colors.textSecondary) }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(inventory.enumerated()), id: \.element.id) { i, item in
                            RewardTile(reward: item.reward, owned: true, qty: item.qty, color: Theme.Colors.cycled(i + 2))
                                .frame(width: 150)
                        }
                    }
                }
            }
        }
    }

    private var links: some View {
        VStack(spacing: 8) {
            link("Check-ins", "history", Theme.Colors.pink, "\(history.count)") { CheckinHistoryView() }
            link("Quests", "goals", Theme.Colors.teal, nil) { QuestsView() }
            link("Leaderboard", "rank", Theme.Colors.yellow, nil) { LeaderboardView() }
            link("Events", "bonus XP", Theme.Colors.red, nil) { EventsView() }
            link("All spots", "campus guide", Theme.Colors.lavender, nil) { SpotsListView() }
        }
    }

    private func link<Dest: View>(_ title: String, _ sub: String, _ color: Color, _ value: String?, @ViewBuilder _ dest: () -> Dest) -> some View {
        NavigationLink(destination: dest) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: -2) {
                    Text(title).font(Theme.Fonts.display(26)).tracking(-0.8)
                    Text(sub).font(Theme.Fonts.caption).opacity(0.55)
                }
                Spacer()
                if let value { Text(value).font(Theme.Fonts.number(28, weight: .regular)) }
                ArrowBadge(color: Theme.foreground(on: color).opacity(0.08), foreground: Theme.foreground(on: color), size: 40)
            }
            .foregroundStyle(Theme.foreground(on: color))
            .padding(.horizontal, 24).frame(height: 78)
            .background(color, in: Capsule())
        }
        .buttonStyle(PressableStyle())
    }

    private var server: some View {
        HStack(spacing: 10) {
            Circle().fill(health?.status == "ok" ? Theme.Colors.green : (health == nil ? Theme.Colors.textSecondary : Theme.Colors.red))
                .frame(width: 10, height: 10)
            Text(health.map { $0.status == "ok" ? "Server online · v\($0.version)" : "Database \($0.database.state)" } ?? "Checking server…")
            Spacer()
            Text(env.config.baseURL.host() ?? "").monospaced()
        }
        .font(Theme.Fonts.micro)
        .foregroundStyle(Theme.Colors.textSecondary)
        .padding(.horizontal, 6)
    }

    private func load() async {
        async let inv = try? env.api.inventory()
        async let h = try? env.api.health()
        async let hist = try? env.api.checkinHistory(limit: 100)
        inventory = await inv ?? []
        health = await h
        history = await hist ?? []
        await env.session.refreshMe()
    }

    private func setSharing(_ on: Bool) async {
        savingSharing = true
        defer { savingSharing = false }
        do { try await env.setSharing(on) } catch { self.error = error.localizedDescription }
    }
}
