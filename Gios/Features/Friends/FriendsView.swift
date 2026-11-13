import SwiftUI

/// Friends: requests, your crew (with live status), sent requests, and search.
struct FriendsView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.selectTab) private var selectTab
    @State private var list: FriendsList?
    @State private var locations: [String: FriendLocation] = [:]
    @State private var query = ""
    @State private var results: [PublicUser] = []
    @State private var sentTo: Set<String> = []
    @State private var busy: Set<String> = []
    @State private var error: String?
    @FocusState private var searching: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                HStack(alignment: .top) {
                    StackedTitle(primary: "Your", secondary: "Crew", size: 48)
                    Spacer()
                    if let list {
                        HStack(spacing: 6) {
                            LineBadge("\(list.friends.count)", color: Theme.Colors.lavender, size: 40)
                            LineBadge("\(locations.values.filter(\.online).count)", color: Theme.Colors.green, size: 40)
                        }
                        .accessibilityLabel("\(list.friends.count) friends")
                    }
                }
                .appear()

                searchField.appear(delay: 0.05)

                if !query.isEmpty { searchResults }
                else if let list {
                    if !list.incoming.isEmpty { requests(list.incoming) }
                    crew(list.friends)
                    if !list.outgoing.isEmpty { sent(list.outgoing) }
                } else {
                    ProgressView().tint(Theme.Colors.yellow).frame(maxWidth: .infinity).padding(.top, 40)
                }
            }
            .padding(Theme.Spacing.m)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .scrollDismissesKeyboard(.interactively)
        .pageBackground()
        .toolbar(.hidden, for: .navigationBar)
        .task(id: query) {
            let q = query.trimmingCharacters(in: .whitespaces)
            guard q.count >= 2 else { results = []; return }
            try? await Task.sleep(for: .milliseconds(300))
            results = (try? await env.api.searchUsers(q)) ?? []
        }
        .task { await load() }
        .refreshable { await load() }
        .errorAlert(message: $error)
    }

    private var searchField: some View {
        FieldBox(icon: "magnifyingglass") {
            HStack {
                TextField("Find by name or email", text: $query)
                    .textInputAutocapitalization(.never).autocorrectionDisabled().focused($searching)
                if !query.isEmpty {
                    Button { query = ""; searching = false } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.Colors.textSecondary) }
                        .accessibilityLabel("Clear search")
                }
            }
        }
    }

    // MARK: Sections

    private var searchResults: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("People", subtitle: results.isEmpty ? "no one found yet" : "\(results.count) found")
            ForEach(Array(results.enumerated()), id: \.element.id) { i, u in
                personRow(u, subtitle: "Level \(u.level)", index: i) {
                    if knownIds.contains(u.id) || sentTo.contains(u.id) {
                        Tag(text: sentTo.contains(u.id) ? "Requested" : "Added", tint: Theme.Colors.textSecondary)
                    } else {
                        CircleButton(systemName: "plus", size: 44, fill: Theme.Colors.yellow) { Task { await add(u) } }
                            .accessibilityLabel("Add \(u.name)")
                    }
                }
            }
        }
    }

    private func requests(_ items: [FriendsList.Item]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Requests", subtitle: "\(items.count) waiting")
            ForEach(items) { item in
                HStack(spacing: 12) {
                    AvatarView(avatar: item.user.avatar, name: item.user.name, size: 52)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(item.user.name).font(Theme.Fonts.display(24)).tracking(-0.6)
                        Text("wants to be friends").font(Theme.Fonts.caption).opacity(0.6)
                    }
                    Spacer()
                    if busy.contains(item.friendshipId) { ProgressView().tint(Theme.Colors.ink) } else {
                        CircleButton(systemName: "xmark", size: 46, fill: Theme.Colors.ink.opacity(0.1), foreground: Theme.Colors.ink) {
                            Task { await act(item.friendshipId) { try await env.api.removeFriendship(item.friendshipId) } }
                        }
                        .accessibilityLabel("Decline \(item.user.name)")
                        CircleButton(systemName: "checkmark", size: 46, fill: Theme.Colors.ink, foreground: Theme.Colors.yellow) {
                            Task { await act(item.friendshipId) { try await env.api.acceptFriend(item.friendshipId) } }
                        }
                        .accessibilityLabel("Accept \(item.user.name)")
                    }
                }
                .foregroundStyle(Theme.Colors.ink)
                .padding(12).padding(.trailing, 4)
                .background(Theme.Colors.yellow, in: Capsule())
                .appear()
            }
        }
    }

    private func crew(_ friends: [FriendsList.Item]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Friends", subtitle: "\(friends.count) total")
            if friends.isEmpty {
                Card { Text("Search above to add your first friend.").font(Theme.Fonts.body).foregroundStyle(Theme.Colors.textSecondary) }
            }
            ForEach(Array(friends.enumerated()), id: \.element.id) { i, item in
                let loc = locations[item.user.id]
                personRow(item.user, subtitle: status(loc), index: i, online: loc?.online) {
                    if loc != nil {
                        Button { selectTab(.map) } label: { ArrowBadge(color: .white, foreground: Theme.Colors.ink, size: 44) }
                            .accessibilityLabel("Show \(item.user.name) on the map")
                    } else {
                        ArrowBadge(systemName: "location.slash.fill", color: Theme.Colors.surface2, foreground: Theme.Colors.textSecondary, size: 44)
                    }
                }
                .contextMenu {
                    Button("Remove friend", systemImage: "person.fill.xmark", role: .destructive) {
                        Task { await act(item.friendshipId) { try await env.api.removeFriendship(item.friendshipId) } }
                    }
                }
                .appear(delay: Double(i) * 0.04)
            }
        }
    }

    private func sent(_ items: [FriendsList.Item]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Sent", subtitle: "pending")
            ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
                personRow(item.user, subtitle: "Request pending", index: i) {
                    Button("Cancel") { Task { await act(item.friendshipId) { try await env.api.removeFriendship(item.friendshipId) } } }
                        .font(Theme.Fonts.bold(14)).foregroundStyle(Theme.Colors.red)
                }
            }
        }
    }

    private func personRow<Trailing: View>(_ u: PublicUser, subtitle: String, index: Int, online: Bool? = nil,
                                           @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 14) {
            AvatarView(avatar: u.avatar, name: u.name, size: 52, online: online)
            VStack(alignment: .leading, spacing: 0) {
                Text(u.name).font(Theme.Fonts.display(24)).tracking(-0.6).foregroundStyle(Theme.Colors.text)
                Text(subtitle).font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
            }
            Spacer()
            trailing()
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.Colors.line).frame(height: 1) }
        .accessibilityElement(children: .combine)
    }

    // MARK: Data

    private var knownIds: Set<String> {
        guard let list else { return [] }
        return Set((list.friends + list.incoming + list.outgoing).map(\.user.id))
    }

    private func status(_ loc: FriendLocation?) -> String {
        guard let loc else { return "Not sharing location" }
        return loc.online ? "Online now" : "Seen \(loc.location.recordedAt.formatted(.relative(presentation: .named)))"
    }

    private func load() async {
        do {
            async let l = env.api.friends()
            async let locs = env.api.friendLocations()
            let newList = try await l
            let newLocs = Dictionary(uniqueKeysWithValues: try await locs.map { ($0.user.id, $0) })
            withAnimation(.spring(response: 0.4)) { list = newList; locations = newLocs }
        } catch APIError.sessionExpired {
        } catch { self.error = error.localizedDescription }
    }

    private func add(_ u: PublicUser) async {
        do {
            try await env.api.sendFriendRequest(to: u.id)
            sentTo.insert(u.id)
            await load()
        } catch { self.error = error.localizedDescription }
    }

    private func act(_ id: String, _ op: () async throws -> Void) async {
        busy.insert(id)
        defer { busy.remove(id) }
        do { try await op(); await load() } catch { self.error = error.localizedDescription }
    }
}
