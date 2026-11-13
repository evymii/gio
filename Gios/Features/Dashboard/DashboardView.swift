import SwiftUI

/// Home: level, event, stats, nearby spots, quests, friends online, weekly rank.
struct DashboardView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var model = DashboardViewModel()

    var body: some View {
        Group {
            switch model.state {
            case .loading:
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            case let .failed(message):
                ContentUnavailableView {
                    Label("Couldn't load your dashboard", systemImage: "exclamationmark.triangle")
                } description: { Text(message) } actions: {
                    Button("Try again") { Task { await model.load(env) } }
                }
            case let .loaded(d):
                content(d)
            }
        }
        .background(Theme.Colors.background.ignoresSafeArea())
        .navigationTitle("Home")
        .task { await model.load(env) }
        .refreshable { await model.load(env) }
        // Reload once a first GPS fix arrives so "nearby" reflects where you are.
        .onChange(of: env.location.location == nil) { _, isNil in
            if !isNil { Task { await model.load(env) } }
        }
        .alert("Gios", isPresented: Binding(get: { model.toast != nil }, set: { if !$0 { model.toast = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(model.toast ?? "") }
    }

    private func content(_ d: Dashboard) -> some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.m) {
                levelCard(d)
                if let event = d.events.first(where: \.isActive) {
                    NavigationLink { EventsView() } label: { eventBanner(event) }.buttonStyle(.plain)
                }
                statsRow(d.stats)
                if !env.location.isAuthorized { locationPrompt }
                nearby(d.nearbySpots)
                quests(d.quests)
                friendsOnline(d.friendsOnline)
                rankCard(d.leaderboard)
            }
            .padding(Theme.Spacing.m)
        }
    }

    // MARK: Sections

    private func levelCard(_ d: Dashboard) -> some View {
        Card {
            HStack(spacing: Theme.Spacing.m) {
                AvatarView(avatar: d.user.avatar, name: d.user.name, size: 56)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hi, \(d.user.name.split(separator: " ").first.map(String.init) ?? d.user.name)")
                        .font(Theme.Fonts.title)
                    Text(d.region.map { "You're at \($0.name)" } ?? "Explore campus to earn XP")
                        .font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
                }
                Spacer()
                VStack(spacing: 0) {
                    Text("LVL").font(.system(size: 10, weight: .bold, design: .rounded)).foregroundStyle(Theme.Colors.textSecondary)
                    Text("\(d.user.level)").font(Theme.Fonts.display(28)).foregroundStyle(Theme.Colors.accent)
                }
            }
            ProgressBar(value: d.user.levelProgress, tint: Theme.Colors.xp, height: 10)
            HStack {
                Text("\(d.user.xp) XP").font(Theme.Fonts.caption.weight(.semibold))
                Spacer()
                Text("\(d.user.nextLevelXp - d.user.xp) XP to level \(d.user.level + 1)")
                    .font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
            }
        }
    }

    private func eventBanner(_ e: GameEvent) -> some View {
        HStack(spacing: Theme.Spacing.s + 4) {
            Image(systemName: "sparkles").font(.title2).foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 2) {
                Text(e.title).font(Theme.Fonts.headline).foregroundStyle(.white)
                Text("\(e.description) Ends \(e.endsAt.formatted(.relative(presentation: .named))).")
                    .font(Theme.Fonts.caption).foregroundStyle(.white.opacity(0.9))
            }
            Spacer()
        }
        .padding(Theme.Spacing.m)
        .background(LinearGradient(colors: [Color(hex: 0xE5488F), Color(hex: 0x8E6CEF)], startPoint: .leading, endPoint: .trailing),
                    in: RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    private func statsRow(_ s: Dashboard.Stats) -> some View {
        HStack(spacing: Theme.Spacing.s) {
            stat("\(s.checkinsTotal)", "Check-ins", "mappin.circle.fill")
            stat("\(s.checkinsThisWeek)", "This week", "calendar")
            stat("\(s.uniqueSpots)", "Spots", "star.circle.fill")
            stat("\(s.friends)", "Friends", "person.2.fill")
        }
    }

    private func stat(_ value: String, _ label: String, _ icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).foregroundStyle(Theme.Colors.accent)
            Text(value).font(Theme.Fonts.number)
            Text(label).font(.system(size: 11, design: .rounded)).foregroundStyle(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.s + 4)
        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.control))
        .accessibilityElement(children: .combine)
    }

    private var locationPrompt: some View {
        Card {
            Label("Turn on location", systemImage: "location.fill").font(Theme.Fonts.headline)
            Text("Gios needs your location to find spots nearby and verify check-ins.")
                .font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
            Button(env.location.isDenied ? "Open Settings" : "Allow location") {
                if env.location.isDenied, let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                } else { env.location.requestPermission() }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func nearby(_ spots: [Spot]) -> some View {
        Card {
            SectionHeader(title: "Nearby spots") { NavigationLink("See all") { SpotsListView() } }
            if spots.isEmpty {
                Text("No spots within 2 km.").font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
            }
            ForEach(spots) { spot in
                HStack(spacing: Theme.Spacing.s + 4) {
                    SpotIcon(type: spot.type)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(spot.name).font(Theme.Fonts.body.weight(.semibold))
                        Text("\(formatDistance(spot.distanceMeters)) · +\(spot.rewardXp) XP")
                            .font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
                    }
                    Spacer()
                    checkinButton(spot)
                }
            }
        }
    }

    @ViewBuilder
    private func checkinButton(_ spot: Spot) -> some View {
        if model.busySpotId == spot.id {
            ProgressView()
        } else if spot.isOnCooldown {
            Label("Done", systemImage: "checkmark.circle.fill").labelStyle(.iconOnly)
                .foregroundStyle(Theme.Colors.online).font(.title3)
                .accessibilityLabel("Checked in recently")
        } else if spot.inRange == true {
            Button("Check in") { Task { await model.checkIn(spot, env: env) } }
                .buttonStyle(.borderedProminent).controlSize(.small)
        } else {
            Text("Too far").font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
        }
    }

    private func quests(_ quests: [Quest]) -> some View {
        Card {
            SectionHeader(title: "Quests") { NavigationLink("See all") { QuestsView() } }
            if quests.isEmpty {
                Text("All quests claimed — nice!").font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
            }
            ForEach(quests) { q in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: q.reward?.icon ?? "flag.fill").foregroundStyle(Theme.Colors.xp)
                        Text(q.title).font(Theme.Fonts.body.weight(.semibold))
                        Spacer()
                        if q.isClaimable {
                            if model.busyQuestId == q.id { ProgressView() } else {
                                Button("Claim") { Task { await model.claim(q, env: env) } }
                                    .buttonStyle(.borderedProminent).tint(Theme.Colors.xp).controlSize(.small)
                            }
                        } else {
                            Text("\(q.progress)/\(q.goal.target)").font(Theme.Fonts.caption.monospacedDigit())
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                    }
                    Text("\(q.description) · +\(q.rewardXp) XP").font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
                    ProgressBar(value: q.fraction, tint: q.isClaimable ? Theme.Colors.xp : Theme.Colors.accent, height: 6)
                }
            }
        }
    }

    private func friendsOnline(_ f: Dashboard.FriendsOnline) -> some View {
        Card {
            SectionHeader(title: "Friends online") { Text("\(f.count) of \(f.total)") }
            if f.users.isEmpty {
                Text("No friends sharing right now.").font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.m) {
                        ForEach(f.users) { o in
                            VStack(spacing: 4) {
                                AvatarView(avatar: o.user.avatar, name: o.user.name, size: 48, online: true)
                                Text(o.user.name).font(Theme.Fonts.caption.weight(.semibold))
                                Text(formatDistance(o.distanceMeters)).font(.system(size: 11, design: .rounded))
                                    .foregroundStyle(Theme.Colors.textSecondary)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
            }
        }
    }

    private func rankCard(_ r: Dashboard.Rank) -> some View {
        NavigationLink { LeaderboardView() } label: {
            HStack(spacing: Theme.Spacing.m) {
                Image(systemName: "trophy.fill").font(.title).foregroundStyle(Theme.Colors.xp)
                VStack(alignment: .leading, spacing: 2) {
                    Text("This week").font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
                    Text(r.rank.map { "Rank #\($0)" } ?? "Not ranked yet").font(Theme.Fonts.headline)
                    Text("\(r.score) XP earned").font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Theme.Colors.textSecondary)
            }
            .padding(Theme.Spacing.m)
            .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        }
        .buttonStyle(.plain)
    }
}
