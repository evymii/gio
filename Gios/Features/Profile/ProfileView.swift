import SwiftUI

/// You: level, location sharing (ghost mode), inventory, server, log out.
struct ProfileView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var inventory: [InventoryEntry] = []
    @State private var health: Health?
    @State private var savingSharing = false
    @State private var error: String?

    var body: some View {
        List {
            if let me = env.session.me {
                Section {
                    HStack(spacing: Theme.Spacing.m) {
                        AvatarView(avatar: me.avatar, name: me.name, size: 64)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(me.name).font(Theme.Fonts.title)
                            Text(me.email).font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
                            Text("Level \(me.level) · \(me.xp) XP").font(Theme.Fonts.caption.weight(.semibold))
                                .foregroundStyle(Theme.Colors.accent)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    Toggle(isOn: Binding(get: { me.isSharing }, set: { on in Task { await setSharing(on) } })) {
                        Label("Share location with friends", systemImage: me.isSharing ? "location.fill" : "location.slash")
                    }
                    .disabled(savingSharing)
                    HStack {
                        Label("Location permission", systemImage: "lock.shield")
                        Spacer()
                        Text(permissionText).foregroundStyle(Theme.Colors.textSecondary)
                    }
                } header: {
                    Text("Privacy")
                } footer: {
                    Text("Only accepted friends can see you, and only while sharing is on. Turn it off for ghost mode. Raw location history is deleted after 7 days.")
                }
            }

            Section("Inventory") {
                if inventory.isEmpty {
                    Text("Complete quests to earn badges and rewards.").foregroundStyle(Theme.Colors.textSecondary)
                }
                ForEach(inventory) { item in
                    HStack(spacing: Theme.Spacing.s + 4) {
                        Image(systemName: item.reward.icon).font(.title3).foregroundStyle(Theme.Colors.xp).frame(width: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.reward.name).font(Theme.Fonts.body.weight(.semibold))
                            Text(item.reward.description).font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
                        }
                        Spacer()
                        if item.qty > 1 { Text("×\(item.qty)").font(Theme.Fonts.caption.weight(.bold)) }
                        Text(item.reward.type.capitalized).font(.system(size: 11, weight: .semibold, design: .rounded))
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Theme.Colors.accentSoft, in: Capsule())
                    }
                }
            }

            Section("App") {
                NavigationLink { LeaderboardView() } label: { Label("Leaderboard", systemImage: "trophy") }
                HStack {
                    Label("Server", systemImage: "server.rack")
                    Spacer()
                    if let health {
                        Circle().fill(health.status == "ok" ? Theme.Colors.online : Theme.Colors.danger).frame(width: 8, height: 8)
                        Text(health.status == "ok" ? "Online · v\(health.version)" : "Database \(health.database.state)")
                            .foregroundStyle(Theme.Colors.textSecondary)
                    } else {
                        ProgressView()
                    }
                }
                Text(env.config.baseURL.absoluteString).font(Theme.Fonts.caption.monospaced())
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            Section {
                Button("Log out", role: .destructive) { Task { await env.signOut() } }
            }
        }
        .navigationTitle("Profile")
        .task {
            async let inv = try? env.api.inventory()
            async let h = try? env.api.health()
            inventory = await inv ?? []
            health = await h
            await env.session.refreshMe()
        }
        .alert("Couldn't update", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(error ?? "") }
    }

    private var permissionText: String {
        switch env.location.permissionName {
        case "when_in_use": "While using"
        case "always": "Always"
        case "denied", "restricted": "Off"
        default: "Not asked"
        }
    }

    private func setSharing(_ on: Bool) async {
        savingSharing = true
        defer { savingSharing = false }
        do { try await env.setSharing(on) } catch { self.error = error.localizedDescription }
    }
}
