import SwiftUI

/// Bold red event card with a giant arrow.
struct EventCard: View {
    let event: GameEvent
    var compact = false

    var body: some View {
        let color = event.isActive ? Theme.Colors.red : Theme.Colors.surface2
        ZStack(alignment: .topLeading) {
            Image(systemName: "arrow.down.right")
                .font(.system(size: compact ? 150 : 210, weight: .black))
                .foregroundStyle(.white.opacity(event.isActive ? 0.18 : 0.06))
                .offset(x: -10, y: -14)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Spacer()
                    LineBadge("×\(event.xpMultiplier.formatted())", color: Theme.Colors.yellow, size: 52)
                }
                Spacer(minLength: compact ? 30 : 80)
                Text(event.title).font(Theme.Fonts.display(compact ? 36 : 44)).tracking(-1.2).foregroundStyle(.white)
                    .lineLimit(2).minimumScaleFactor(0.7)
                HStack {
                    Text(event.description).font(Theme.Fonts.caption)
                    Spacer()
                    Text(event.isActive ? "Ends \(event.endsAt.formatted(.relative(presentation: .named)))"
                                        : "Starts \(event.startsAt.formatted(.relative(presentation: .named)))")
                        .font(Theme.Fonts.micro)
                }
                .foregroundStyle(.white.opacity(0.75))
                SegmentBar(fraction: elapsed, segments: 6, color: Theme.Colors.yellow, track: .white.opacity(0.2))
                    .padding(.top, 4)
            }
            .padding(22)
        }
        .frame(maxWidth: .infinity, minHeight: compact ? 230 : 320, alignment: .topLeading)
        .background(color, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var elapsed: Double {
        let total = event.endsAt.timeIntervalSince(event.startsAt)
        guard total > 0 else { return 0 }
        return min(1, max(0, Date().timeIntervalSince(event.startsAt) / total))
    }
}

/// Campus events: happening now and coming up.
struct EventsView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var events: [GameEvent]?
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                StackedTitle(primary: "Events", secondary: "Bonus XP on campus", size: 40).appear()
                if let events {
                    if events.isEmpty {
                        Card { Text("No events right now — check back soon.").font(Theme.Fonts.body).foregroundStyle(Theme.Colors.textSecondary) }
                    }
                    ForEach(Array(events.enumerated()), id: \.element.id) { i, e in
                        EventCard(event: e).appear(delay: Double(i) * 0.08).scrollFade()
                    }
                } else {
                    ProgressView().tint(Theme.Colors.yellow).frame(maxWidth: .infinity).padding(.top, 60)
                }
            }
            .padding(Theme.Spacing.m)
        }
        .pageBackground()
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
        .errorAlert(message: $error)
    }

    private func load() async {
        do { events = try await env.api.events() }
        catch APIError.sessionExpired {}
        catch { self.error = error.localizedDescription }
    }
}
