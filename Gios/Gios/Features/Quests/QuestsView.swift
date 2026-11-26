import SwiftUI

/// All quests as habit pills, filterable; tap a ready one to claim.
struct QuestsView: View {
    enum Filter: String, CaseIterable { case all = "All", ready = "Ready", active = "Active", done = "Done" }

    @Environment(AppEnvironment.self) private var env
    @State private var quests: [Quest]?
    @State private var filter: Filter = .all
    @State private var busyId: String?
    @State private var claimed: ClaimResult?
    @State private var error: String?

    private var shown: [Quest] {
        let q = quests ?? []
        switch filter {
        case .all: return q.sorted { order($0) < order($1) }
        case .ready: return q.filter(\.isClaimable)
        case .active: return q.filter { $0.status == "in_progress" }
        case .done: return q.filter(\.isClaimed)
        }
    }
    private func order(_ q: Quest) -> Int { q.isClaimable ? 0 : (q.isClaimed ? 2 : 1) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    StackedTitle(primary: "Quests", secondary: "Goals & XP", size: 40)
                    Spacer()
                    if let quests {
                        LineBadge("\(quests.filter(\.isClaimable).count)", color: Theme.Colors.yellow, size: 44)
                            .accessibilityLabel("\(quests.filter(\.isClaimable).count) ready to claim")
                    }
                }
                .appear()
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(Filter.allCases, id: \.self) { f in Chip(title: f.rawValue, selected: filter == f) { filter = f } }
                    }
                }
                if quests == nil {
                    ProgressView().tint(Theme.Colors.yellow).frame(maxWidth: .infinity).padding(.top, 40)
                } else if shown.isEmpty {
                    PillRow(title: "Nothing here", value: "0", color: Theme.Colors.surface2, filled: false)
                }
                VStack(spacing: 8) {
                    ForEach(Array(shown.enumerated()), id: \.element.id) { i, q in
                        Button { if q.isClaimable { Task { await claim(q) } } } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                QuestPill(quest: q, index: i, busy: busyId == q.id)
                                HStack(spacing: 6) {
                                    Text(q.description).font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
                                    Spacer()
                                    Tag(text: "+\(q.rewardXp) XP")
                                }
                                .padding(.horizontal, 12).padding(.bottom, 6)
                            }
                        }
                        .buttonStyle(PressableStyle())
                        .disabled(!q.isClaimable)
                        .scrollFade()
                    }
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: filter)
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: quests?.map(\.status))
            }
            .padding(Theme.Spacing.m)
        }
        .pageBackground()
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
        .sheet(item: Binding(get: { claimed.map(ClaimBox.init) }, set: { if $0 == nil { claimed = nil } })) { box in
            ClaimedSheet(result: box.result)
        }
        .errorAlert(message: $error)
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
            claimed = try await env.claim(q)
            await load()
        } catch { self.error = error.localizedDescription }
    }
}

private struct ClaimBox: Identifiable { let result: ClaimResult; var id: Int { result.user.xp } }

/// Celebration after claiming a quest.
private struct ClaimedSheet: View {
    let result: ClaimResult
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            HStack {
                LineBadge(icon: "star.fill", color: Theme.Colors.ink, size: 64, foreground: Theme.Colors.yellow)
                Spacer()
                CircleButton(systemName: "xmark", size: 48, fill: Theme.Colors.ink.opacity(0.1), foreground: Theme.Colors.ink) { dismiss() }
            }
            Spacer()
            Text("+\(result.xpAwarded)").font(Theme.Fonts.number(110, weight: .regular)).tracking(-5)
            StackedTitle(primary: "XP earned", secondary: "Quest complete",
                         size: 36, primaryColor: Theme.Colors.ink, secondaryColor: Theme.Colors.ink.opacity(0.5))
            if result.user.leveledUp {
                Tag(text: "LEVEL UP → \(result.user.level)", tint: Theme.Colors.ink, filled: true)
            }
            Button("Nice") { dismiss() }.buttonStyle(PillButtonStyle(fill: Theme.Colors.ink))
        }
        .foregroundStyle(Theme.Colors.ink)
        .padding(Theme.Spacing.l)
        .presentationDetents([.medium])
        .presentationCornerRadius(40)
        .presentationBackground(Theme.Colors.yellow)
        .sensoryFeedback(.success, trigger: true)
    }
}
