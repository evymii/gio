import SwiftUI

/// Campus events: happening now and coming up.
struct EventsView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var events: [GameEvent]?
    @State private var error: String?

    var body: some View {
        List {
            if let events {
                if events.isEmpty {
                    ContentUnavailableView("No events right now", systemImage: "calendar", description: Text("Check back soon."))
                }
                let now = events.filter(\.isActive), next = events.filter { !$0.isActive }
                if !now.isEmpty { Section("Happening now") { ForEach(now) { row($0) } } }
                if !next.isEmpty { Section("Coming up") { ForEach(next) { row($0) } } }
            } else {
                ProgressView().frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Events")
        .task { await load() }
        .refreshable { await load() }
        .errorAlert(message: $error)
    }

    private func row(_ e: GameEvent) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.s + 4) {
            Image(systemName: "sparkles").font(.title3).foregroundStyle(Color(hex: 0xE5488F)).frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(e.title).font(Theme.Fonts.body.weight(.semibold))
                    Tag(text: "×\(e.xpMultiplier.formatted()) XP", tint: Theme.Colors.xp)
                }
                Text(e.description).font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
                Text(e.isActive ? "Ends \(e.endsAt.formatted(.relative(presentation: .named)))"
                                : "\(e.startsAt.formatted(date: .abbreviated, time: .shortened)) – \(e.endsAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.system(size: 11, design: .rounded)).foregroundStyle(Theme.Colors.textSecondary)
            }
        }
        .padding(.vertical, 2)
    }

    private func load() async {
        do { events = try await env.api.events() }
        catch APIError.sessionExpired {}
        catch { self.error = error.localizedDescription }
    }
}
