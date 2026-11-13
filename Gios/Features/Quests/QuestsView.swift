import SwiftUI

/// Every active quest with your progress: ready to claim, in progress, done.
struct QuestsView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var quests: [Quest]?
    @State private var busyId: String?
    @State private var message: String?
    @State private var error: String?

    var body: some View {
        List {
            if let quests {
                section("Ready to claim", quests.filter(\.isClaimable))
                section("In progress", quests.filter { $0.status == "in_progress" })
                section("Completed", quests.filter(\.isClaimed))
            } else {
                ProgressView().frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Quests")
        .task { await load() }
        .refreshable { await load() }
        .alert("Quest claimed", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("Nice!", role: .cancel) {}
        } message: { Text(message ?? "") }
        .errorAlert(message: $error)
    }

    @ViewBuilder
    private func section(_ title: String, _ items: [Quest]) -> some View {
        if !items.isEmpty {
            Section(title) {
                ForEach(items) { q in row(q) }
            }
        }
    }

    private func row(_ q: Quest) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: Theme.Spacing.s + 4) {
                Image(systemName: q.reward?.icon ?? "flag.fill")
                    .font(.title3).foregroundStyle(q.isClaimed ? Theme.Colors.textSecondary : Theme.Colors.xp).frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(q.title).font(Theme.Fonts.body.weight(.semibold))
                    Text(q.description).font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
                    HStack(spacing: 6) {
                        Tag(text: "+\(q.rewardXp) XP", tint: Theme.Colors.xp)
                        if let r = q.reward { Tag(text: r.name) }
                    }
                    .padding(.top, 2)
                }
                Spacer()
                if q.isClaimable {
                    if busyId == q.id { ProgressView() } else {
                        Button("Claim") { Task { await claim(q) } }
                            .buttonStyle(.borderedProminent).tint(Theme.Colors.xp).controlSize(.small)
                    }
                } else if q.isClaimed {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(Theme.Colors.online).accessibilityLabel("Claimed")
                } else {
                    Text("\(q.progress)/\(q.goal.target)").font(Theme.Fonts.caption.monospacedDigit())
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
            if !q.isClaimed {
                ProgressBar(value: q.fraction, tint: q.isClaimable ? Theme.Colors.xp : Theme.Colors.accent, height: 6)
            }
        }
        .padding(.vertical, 4)
    }

    private func load() async {
        do { quests = try await env.api.quests() }
        catch APIError.sessionExpired {}
        catch { self.error = error.localizedDescription }
    }

    private func claim(_ q: Quest) async {
        busyId = q.id
        defer { busyId = nil }
        do {
            let r = try await env.claim(q)
            var lines = ["+\(r.xpAwarded) XP"]
            if let reward = r.reward { lines.append("\(reward.name) added to your rewards") }
            if r.user.leveledUp { lines.append("Level up! You're now level \(r.user.level).") }
            message = lines.joined(separator: "\n")
            await load()
        } catch { self.error = error.localizedDescription }
    }
}
