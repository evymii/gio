import SwiftUI

/// Friends, requests, and finding people to add.
struct FriendsView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var list: FriendsList?
    @State private var locations: [String: FriendLocation] = [:]
    @State private var query = ""
    @State private var results: [PublicUser] = []
    @State private var sentTo: Set<String> = []
    @State private var error: String?

    var body: some View {
        List {
            if !query.isEmpty {
                Section("People") {
                    if results.isEmpty { Text("No one found").foregroundStyle(Theme.Colors.textSecondary) }
                    ForEach(results) { u in
                        HStack {
                            row(u, subtitle: "Level \(u.level)")
                            Spacer()
                            if knownIds.contains(u.id) || sentTo.contains(u.id) {
                                Text(sentTo.contains(u.id) ? "Requested" : "Added").font(Theme.Fonts.caption)
                                    .foregroundStyle(Theme.Colors.textSecondary)
                            } else {
                                Button("Add") { Task { await add(u) } }.buttonStyle(.borderedProminent).controlSize(.small)
                            }
                        }
                    }
                }
            } else if let list {
                if !list.incoming.isEmpty {
                    Section("Requests") {
                        ForEach(list.incoming) { item in
                            HStack {
                                row(item.user, subtitle: "wants to be friends")
                                Spacer()
                                Button("Accept") { Task { await act { try await env.api.acceptFriend(item.friendshipId) } } }
                                    .buttonStyle(.borderedProminent).controlSize(.small)
                                Button(role: .destructive) { Task { await act { try await env.api.removeFriendship(item.friendshipId) } } } label: {
                                    Image(systemName: "xmark")
                                }
                                .buttonStyle(.bordered).controlSize(.small)
                                .accessibilityLabel("Decline")
                            }
                        }
                    }
                }
                Section("Friends (\(list.friends.count))") {
                    if list.friends.isEmpty { Text("Search above to add friends.").foregroundStyle(Theme.Colors.textSecondary) }
                    ForEach(list.friends) { item in
                        let loc = locations[item.user.id]
                        row(item.user, subtitle: status(loc), online: loc?.online ?? false)
                            .swipeActions {
                                Button("Remove", role: .destructive) {
                                    Task { await act { try await env.api.removeFriendship(item.friendshipId) } }
                                }
                            }
                    }
                }
                if !list.outgoing.isEmpty {
                    Section("Sent") {
                        ForEach(list.outgoing) { item in
                            HStack {
                                row(item.user, subtitle: "request pending")
                                Spacer()
                                Button("Cancel") { Task { await act { try await env.api.removeFriendship(item.friendshipId) } } }
                                    .font(Theme.Fonts.caption)
                            }
                        }
                    }
                }
            } else {
                ProgressView().frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Friends")
        .searchable(text: $query, prompt: "Find by name or email")
        .task(id: query) {
            guard query.trimmingCharacters(in: .whitespaces).count >= 2 else { results = []; return }
            try? await Task.sleep(for: .milliseconds(300)) // debounce typing
            results = (try? await env.api.searchUsers(query.trimmingCharacters(in: .whitespaces))) ?? []
        }
        .task { await load() }
        .refreshable { await load() }
        .alert("Something went wrong", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(error ?? "") }
    }

    private var knownIds: Set<String> {
        guard let list else { return [] }
        return Set((list.friends + list.incoming + list.outgoing).map(\.user.id))
    }

    private func row(_ u: PublicUser, subtitle: String, online: Bool? = nil) -> some View {
        HStack(spacing: Theme.Spacing.s + 4) {
            AvatarView(avatar: u.avatar, name: u.name, size: 40, online: online)
            VStack(alignment: .leading, spacing: 2) {
                Text(u.name).font(Theme.Fonts.body.weight(.semibold))
                Text(subtitle).font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
            }
        }
    }

    private func status(_ loc: FriendLocation?) -> String {
        guard let loc else { return "Not sharing location" }
        return loc.online ? "Online now" : "Seen \(loc.location.recordedAt.formatted(.relative(presentation: .named)))"
    }

    private func load() async {
        do {
            async let l = env.api.friends()
            async let locs = env.api.friendLocations()
            list = try await l
            locations = Dictionary(uniqueKeysWithValues: try await locs.map { ($0.user.id, $0) })
        } catch APIError.sessionExpired {
        } catch { self.error = error.localizedDescription }
    }

    private func add(_ u: PublicUser) async {
        await act { try await env.api.sendFriendRequest(to: u.id) }
        sentTo.insert(u.id)
    }

    private func act(_ op: () async throws -> Void) async {
        do { try await op(); await load() } catch { self.error = error.localizedDescription }
    }
}
