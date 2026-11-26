import SwiftUI

/// Home: level, progress arc, event, nearby spots (stacked cards), quests (pills), friends, rank.
struct DashboardView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.selectTab) private var selectTab
    @State private var model = DashboardViewModel()
    @State private var selected: Spot?

    var body: some View {
        Group {
            switch model.state {
            case .loading:
                ProgressView().tint(Theme.Colors.yellow).frame(maxWidth: .infinity, maxHeight: .infinity)
            case let .failed(message):
                VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                    StackedTitle(primary: "Couldn't load", secondary: "your campus", size: 40)
                    Text(message).font(Theme.Fonts.body).foregroundStyle(Theme.Colors.textSecondary)
                    Button("Try again") { Task { await model.load(env) } }.buttonStyle(PillButtonStyle())
                }
                .padding(Theme.Spacing.l)
                .frame(maxHeight: .infinity)
            case let .loaded(d):
                content(d)
            }
        }
        .pageBackground()
        .toolbar(.hidden, for: .navigationBar)
        .task { await model.load(env) }
        .refreshable { await model.load(env) }
        .onChange(of: env.location.location == nil) { _, isNil in if !isNil { Task { await model.load(env) } } }
        .sheet(item: $selected) { spot in
            SpotSheet(spot: spot) { Task { await model.load(env) } }
        }
        .alert("Gios", isPresented: Binding(get: { model.toast != nil }, set: { if !$0 { model.toast = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(model.toast ?? "") }
        .sensoryFeedback(.success, trigger: model.toast)
    }

    private func content(_ d: Dashboard) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                header(d).appear()
                today(d).appear(delay: 0.04)
                statTiles(d).appear(delay: 0.08)
                actions.appear(delay: 0.1)
                numbers(d).appear(delay: 0.12)
                arc(d).appear(delay: 0.14)
                if !env.location.isAuthorized { locationPrompt }
                nearby(d.nearbySpots)
                quests(d.quests)
                friends(d.friendsOnline)
                rank(d.leaderboard)
            }
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.top, Theme.Spacing.s)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: Header

    private func header(_ d: Dashboard) -> some View {
        HStack(alignment: .top) {
            StackedTitle(primary: "Hi \(d.user.name.split(separator: " ").first.map(String.init) ?? d.user.name)",
                         secondary: Date.now.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)), size: 40)
            Spacer()
            Button { selectTab(.profile) } label: { AvatarView(avatar: d.user.avatar, name: d.user.name, size: 52) }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("Profile")
        }
    }

    /// "Today" sentence built from live data.
    private func today(_ d: Dashboard) -> some View {
        var parts: [(String, Bool)] = [("Today you're on ", false), ("campus", true)]
        if d.friendsOnline.count > 0 {
            parts += [(" with ", false), ("\(d.friendsOnline.count) friend\(d.friendsOnline.count == 1 ? "" : "s") online", true)]
        }
        if let spot = d.nearbySpots.first(where: { $0.inRange == true && !$0.isOnCooldown }) {
            parts += [(". Check in at ", false), (spot.name, true)]
        }
        if let q = d.quests.first(where: \.isClaimable) {
            parts += [(" and claim ", false), (q.title, true)]
        }
        parts.append((".", false))
        return HighlightSentence(parts: parts)
    }

    private func statTiles(_ d: Dashboard) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            FolderStat(icon: "mappin.and.ellipse", value: "\(d.stats.checkinsTotal)", label: "Check-ins", color: Theme.Colors.lime)
            FolderStat(icon: "calendar", value: "\(d.stats.checkinsThisWeek)", label: "This week", color: Theme.Colors.green)
            FolderStat(icon: "star.fill", value: "\(d.stats.uniqueSpots)", label: "Spots found", color: Theme.Colors.coral)
            FolderStat(icon: "person.2.fill", value: "\(d.stats.friends)", label: "Friends", color: Theme.Colors.teal)
        }
    }

    private var actions: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            Button { selectTab(.map) } label: { ActionTile(title: "Open\nlive map", color: .white) }
            Button { selectTab(.friends) } label: { ActionTile(title: "Find\nfriends", color: Theme.Colors.lavender) }
            NavigationLink { QuestsView() } label: { ActionTile(title: "Quests &\nXP", color: Theme.Colors.yellow) }
            NavigationLink { LeaderboardView() } label: { ActionTile(title: "Leader-\nboard", color: Theme.Colors.surface2) }
        }
        .buttonStyle(PressableStyle())
    }

    private func numbers(_ d: Dashboard) -> some View {
        HStack(alignment: .lastTextBaseline) {
            BigStat(value: "\(d.user.level)", unit: "Level", size: 72)
            Spacer()
            BigStat(value: "\(d.user.xp)", unit: "XP", size: 72)
        }
    }

    private func arc(_ d: Dashboard) -> some View {
        let questFraction = d.quests.isEmpty ? 1 : d.quests.map(\.fraction).reduce(0, +) / Double(d.quests.count)
        let tracks: [(TrackArc.Track, String, String)] = [
            (.init(id: "xp", fraction: d.user.levelProgress, color: Theme.Colors.yellow), "Next level", "\(d.user.nextLevelXp - d.user.xp) XP"),
            (.init(id: "week", fraction: min(1, Double(d.stats.checkinsThisWeek) / 7), color: Theme.Colors.red), "This week", "\(d.stats.checkinsThisWeek)/7"),
            (.init(id: "quests", fraction: questFraction, color: Theme.Colors.teal), "Quests", "\(Int(questFraction * 100))%"),
            (.init(id: "friends", fraction: d.friendsOnline.total == 0 ? 0 : Double(d.friendsOnline.count) / Double(d.friendsOnline.total),
                   color: Theme.Colors.lavender), "Friends on", "\(d.friendsOnline.count)/\(d.friendsOnline.total)"),
        ]
        return Card {
            TrackArc(tracks: tracks.map(\.0)).frame(height: 160)
            Divider().overlay(Theme.Colors.line)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 14) {
                ForEach(tracks, id: \.0.id) { t, label, value in
                    HStack(spacing: 10) {
                        Circle().fill(t.color).frame(width: 14, height: 14)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(value).font(Theme.Fonts.bold(17))
                            Text(label).font(Theme.Fonts.micro).foregroundStyle(Theme.Colors.textSecondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private var locationPrompt: some View {
        Card(color: Theme.Colors.blue) {
            HStack {
                LineBadge(icon: "location.fill", color: .white, size: 44, foreground: Theme.Colors.blue)
                Spacer()
            }
            StackedTitle(primary: "Turn on", secondary: "location", size: 30, primaryColor: .white, secondaryColor: .white.opacity(0.6))
            Text("Needed to find spots near you and verify check-ins.").font(Theme.Fonts.caption).foregroundStyle(.white.opacity(0.8))
            Button(env.location.isDenied ? "Open Settings" : "Allow location") {
                if env.location.isDenied, let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                else { env.location.requestPermission() }
            }
            .buttonStyle(PillButtonStyle(fill: .white))
        }
    }

    // MARK: Nearby

    private func nearby(_ spots: [Spot]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Nearby", subtitle: "\(spots.count) spots") {
                NavigationLink("See all") { SpotsListView() }
            }
            if spots.isEmpty {
                Text("No spots within 2 km.").font(Theme.Fonts.body).foregroundStyle(Theme.Colors.textSecondary)
            } else {
                CardStack(items: Array(spots.prefix(4))) { _, spot in
                    Button { selected = spot } label: { SpotCard(spot: spot, distance: spot.distanceMeters) }
                        .buttonStyle(PressableStyle())
                }
            }
        }
    }

    // MARK: Quests

    private func quests(_ quests: [Quest]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Quests", subtitle: "tap to claim") { NavigationLink("See all") { QuestsView() } }
            VStack(spacing: 8) {
                if quests.isEmpty {
                    PillRow(title: "All claimed", value: "✓", color: Theme.Colors.green)
                }
                ForEach(Array(quests.enumerated()), id: \.element.id) { i, q in
                    Button {
                        if q.isClaimable { Task { await model.claim(q, env: env) } }
                    } label: {
                        QuestPill(quest: q, index: i, busy: model.busyQuestId == q.id)
                    }
                    .buttonStyle(PressableStyle())
                    .disabled(!q.isClaimable)
                    .appear(delay: Double(i) * 0.05)
                }
            }
        }
    }

    // MARK: Friends

    private func friends(_ f: Dashboard.FriendsOnline) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Friends", subtitle: "online now") {
                Button("\(f.count)/\(f.total)") { selectTab(.friends) }
            }
            if f.users.isEmpty {
                Card { Text("No friends sharing right now.").font(Theme.Fonts.body).foregroundStyle(Theme.Colors.textSecondary) }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(f.users) { o in
                            Button { selectTab(.map) } label: {
                                VStack(spacing: 6) {
                                    AvatarView(avatar: o.user.avatar, name: o.user.name, size: 64, online: true)
                                    Text(o.user.name).font(Theme.Fonts.bold(14)).foregroundStyle(Theme.Colors.text)
                                    Text(formatDistance(o.distanceMeters)).font(Theme.Fonts.micro).foregroundStyle(Theme.Colors.textSecondary)
                                }
                            }
                            .buttonStyle(PressableStyle())
                            .accessibilityLabel("\(o.user.name), \(formatDistance(o.distanceMeters)) away")
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
    }

    // MARK: Rank

    private func rank(_ r: Dashboard.Rank) -> some View {
        NavigationLink { LeaderboardView() } label: {
            Card(color: Theme.Colors.yellow) {
                HStack {
                    LineBadge(icon: "trophy.fill", color: Theme.Colors.ink, size: 44, foreground: Theme.Colors.yellow)
                    Spacer()
                    ArrowBadge()
                }
                HStack(alignment: .lastTextBaseline) {
                    StackedTitle(primary: "This week", secondary: "\(r.score) XP earned", size: 26,
                                 primaryColor: Theme.Colors.ink, secondaryColor: Theme.Colors.ink.opacity(0.5))
                    Spacer()
                    Text(r.rank.map { "#\($0)" } ?? "–").font(Theme.Fonts.number(64, weight: .regular)).tracking(-2)
                        .foregroundStyle(Theme.Colors.ink)
                }
            }
        }
        .buttonStyle(PressableStyle())
    }
}

/// A spot as a colorful stack card (used on Home and the spots list).
struct SpotCard: View {
    let spot: Spot
    let distance: Double?

    var body: some View {
        let style = Theme.spotStyle(spot.type)
        let parts = distanceParts(distance)
        let status = spot.isOnCooldown ? "Checked in" : (spot.inRange == true ? "In range — check in" : spot.type.capitalized)
        StackCard(color: style.color, title: spot.name, subtitle: "+\(spot.rewardXp) XP · \(status)",
                  value: parts.value, unit: parts.unit,
                  arrow: spot.isOnCooldown ? "checkmark" : (spot.inRange == true ? "arrow.up.right" : "arrow.right")) {
            let fg = Theme.foreground(on: style.color)
            Circle().strokeBorder(fg.opacity(0.25), lineWidth: 1.5)
                .frame(width: 40, height: 40)
                .overlay(Image(systemName: style.icon).font(.system(size: 17, weight: .bold)).foregroundStyle(fg))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(spot.name), \(formatDistance(distance)), \(spot.rewardXp) XP, \(status)")
    }
}

/// A quest as a habit-style pill.
struct QuestPill: View {
    let quest: Quest
    let index: Int
    var busy = false

    var body: some View {
        let color: Color = quest.isClaimable ? Theme.Colors.yellow : Theme.Colors.cycled(index + 3)
        ZStack(alignment: .trailing) {
            PillRow(title: quest.title,
                    value: quest.isClaimable ? "Claim" : (quest.isClaimed ? "✓" : "\(quest.progress)/\(quest.goal.target)"),
                    color: quest.isClaimed ? Theme.Colors.surface2 : color,
                    filled: quest.isClaimable || quest.isClaimed || quest.progress > 0,
                    struck: quest.isClaimed)
                .opacity(busy ? 0.5 : 1)
            if busy { ProgressView().tint(Theme.Colors.ink).padding(.trailing, 28) }
        }
        .accessibilityLabel("\(quest.title), \(quest.isClaimable ? "ready to claim" : "\(quest.progress) of \(quest.goal.target)")")
    }
}
