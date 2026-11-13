import SwiftUI

/// All rewards: what you own (with quantity) and what's still locked.
struct RewardsView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var catalog: [Reward]?
    @State private var owned: [String: InventoryEntry] = [:]
    @State private var error: String?

    var body: some View {
        List {
            if let catalog {
                let mine = catalog.filter { owned[$0.id] != nil }
                let locked = catalog.filter { owned[$0.id] == nil }
                Section {
                    if mine.isEmpty { Text("Complete quests to earn your first reward.").foregroundStyle(Theme.Colors.textSecondary) }
                    ForEach(mine) { r in row(r, entry: owned[r.id]) }
                } header: { Text("Yours (\(mine.count))") }
                if !locked.isEmpty {
                    Section("Locked") { ForEach(locked) { r in row(r, entry: nil) } }
                }
            } else {
                ProgressView().frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Rewards")
        .task { await load() }
        .refreshable { await load() }
        .errorAlert(message: $error)
    }

    private func row(_ r: Reward, entry: InventoryEntry?) -> some View {
        HStack(spacing: Theme.Spacing.s + 4) {
            Image(systemName: entry == nil ? "lock.fill" : r.icon)
                .font(.title3)
                .foregroundStyle(entry == nil ? Theme.Colors.textSecondary : Theme.Colors.xp)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(r.name).font(Theme.Fonts.body.weight(.semibold))
                Text(r.description).font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
                if let entry {
                    Text("Earned \(entry.claimedAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.system(size: 11, design: .rounded)).foregroundStyle(Theme.Colors.textSecondary)
                }
            }
            Spacer()
            if let entry, entry.qty > 1 { Text("×\(entry.qty)").font(Theme.Fonts.caption.weight(.bold)) }
            Tag(text: r.type.capitalized, tint: entry == nil ? .gray : Theme.Colors.accent)
        }
        .opacity(entry == nil ? 0.7 : 1)
        .accessibilityElement(children: .combine)
    }

    private func load() async {
        do {
            async let c = env.api.rewards()
            async let i = env.api.inventory()
            catalog = try await c
            owned = Dictionary(uniqueKeysWithValues: try await i.map { ($0.reward.id, $0) })
        } catch APIError.sessionExpired {
        } catch { self.error = error.localizedDescription }
    }
}
