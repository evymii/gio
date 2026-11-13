import SwiftUI

/// Pictogram reward tile (signage style). Locked tiles are dark with a lock.
struct RewardTile: View {
    let reward: Reward
    let owned: Bool
    var qty = 1
    var color: Color

    var body: some View {
        let bg = owned ? color : Theme.Colors.surface
        let fg = owned ? Theme.foreground(on: color) : Theme.Colors.textSecondary
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Image(systemName: owned ? reward.icon : "lock.fill").font(.system(size: 40, weight: .bold))
                Spacer()
                if owned && qty > 1 { Text("×\(qty)").font(Theme.Fonts.bold(16)) }
            }
            Spacer(minLength: 18)
            Text(reward.name).font(Theme.Fonts.display(20)).tracking(-0.5).lineLimit(2).minimumScaleFactor(0.8)
            Text(reward.type.uppercased()).font(Theme.Fonts.micro).opacity(0.6)
        }
        .foregroundStyle(fg)
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 170, alignment: .topLeading)
        .background(bg, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            if !owned { RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(Theme.Colors.line, lineWidth: 1.5) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(reward.name), \(reward.type), \(owned ? "earned" : "locked")")
    }
}

/// All rewards: earned (colorful) and locked (dark).
struct RewardsView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var catalog: [Reward]?
    @State private var owned: [String: InventoryEntry] = [:]
    @State private var selected: Reward?
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                StackedTitle(primary: "Rewards", secondary: "\(owned.count) of \(catalog?.count ?? 0) earned", size: 40).appear()
                if let catalog {
                    let sorted = catalog.sorted { (owned[$0.id] == nil ? 1 : 0, $0.name) < (owned[$1.id] == nil ? 1 : 0, $1.name) }
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        ForEach(Array(sorted.enumerated()), id: \.element.id) { i, r in
                            Button { selected = r } label: {
                                RewardTile(reward: r, owned: owned[r.id] != nil, qty: owned[r.id]?.qty ?? 0, color: Theme.Colors.cycled(i + 2))
                            }
                            .buttonStyle(PressableStyle())
                            .appear(delay: Double(i) * 0.04)
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
        .task { await load() }
        .refreshable { await load() }
        .alert(selected?.name ?? "", isPresented: Binding(get: { selected != nil }, set: { if !$0 { selected = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            if let s = selected {
                Text(s.description + (owned[s.id].map { "\nEarned \($0.claimedAt.formatted(date: .abbreviated, time: .omitted))" } ?? "\nComplete its quest to unlock."))
            }
        }
        .errorAlert(message: $error)
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
