import SwiftUI

/// Four pages with a floating round-button bar; switching slides between pages.
struct MainTabView: View {
    enum Tab: Int, CaseIterable {
        case home, map, friends, profile
        var icon: String {
            switch self {
            case .home: "house.fill"
            case .map: "map.fill"
            case .friends: "person.2.fill"
            case .profile: "person.crop.circle.fill"
            }
        }
        var title: String {
            switch self {
            case .home: "Home"
            case .map: "Map"
            case .friends: "Friends"
            case .profile: "Profile"
            }
        }
    }

    @State private var tab: Tab = Tab(rawValue: MainTabView.initialTab) ?? .home
    @State private var direction: Edge = .trailing

    var body: some View {
        #if DEBUG
        if let screen = Self.debugScreen {
            NavigationStack { screen }
        } else { pages }
        #else
        pages
        #endif
    }

    private var pages: some View {
        ZStack {
            ForEach(Tab.allCases, id: \.self) { t in
                if t == tab {
                    NavigationStack { page(t) }
                        .transition(.asymmetric(insertion: .push(from: direction), removal: .push(from: direction)))
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { bar }
        .background(Theme.Colors.background.ignoresSafeArea())
        .environment(\.selectTab, { select($0) })
    }

    @ViewBuilder private func page(_ t: Tab) -> some View {
        switch t {
        case .home: DashboardView()
        case .map: CampusMapView()
        case .friends: FriendsView()
        case .profile: ProfileView()
        }
    }

    private func select(_ t: Tab) {
        guard t != tab else { return }
        direction = t.rawValue > tab.rawValue ? .trailing : .leading
        withAnimation(.spring(response: 0.42, dampingFraction: 0.9)) { tab = t }
    }

    private var bar: some View {
        HStack(spacing: 10) {
            ForEach(Tab.allCases, id: \.self) { t in
                Button { select(t) } label: {
                    HStack(spacing: 8) {
                        Image(systemName: t.icon).font(.system(size: 18, weight: .bold))
                        if t == tab { Text(t.title).font(Theme.Fonts.bold(15)).transition(.scale.combined(with: .opacity)) }
                    }
                    .foregroundStyle(t == tab ? Theme.Colors.ink : Theme.Colors.text)
                    .frame(height: 56)
                    .frame(minWidth: 56)
                    .padding(.horizontal, t == tab ? 18 : 0)
                    .background {
                        if t == tab { Capsule().fill(Theme.Colors.yellow) }
                        else { Circle().strokeBorder(Theme.Colors.line, lineWidth: 1.5) }
                    }
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(t.title)
                .accessibilityAddTraits(t == tab ? .isSelected : [])
            }
        }
        .padding(8)
        .background(.black.opacity(0.92), in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.Colors.line, lineWidth: 1))
        .padding(.bottom, 6)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: tab)
        .sensoryFeedback(.selection, trigger: tab)
    }

    /// DEBUG: `-tab 1` opens the Map tab (screenshots/QA).
    private static var initialTab: Int {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-tab"), i + 1 < args.count, let n = Int(args[i + 1]) { return n }
        #endif
        return 0
    }

    #if DEBUG
    /// DEBUG: `-open quests|history|spots|edit|spot|leaderboard` opens one page directly.
    @ViewBuilder private static var debugScreen: (some View)? {
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-open"), i + 1 < args.count {
            switch args[i + 1] {
            case "quests": QuestsView()
            case "history": CheckinHistoryView()
            case "spots": SpotsListView()
            case "edit": EditProfileView()
            case "spot": DebugSpotSheet()
            default: LeaderboardView()
            }
        }
    }
    #endif
}

#if DEBUG
/// Shows the spot sheet for the nearest spot (screenshots/QA).
private struct DebugSpotSheet: View {
    @Environment(AppEnvironment.self) private var env
    @State private var spot: Spot?
    var body: some View {
        Color.black.ignoresSafeArea()
            .sheet(item: $spot) { SpotSheet(spot: $0) {} }
            .task {
                let pos = try? await env.api.dashboard(at: env.location.location?.coordinate).position
                if let pos { spot = try? await env.api.nearbySpots(at: pos.coordinate).first }
            }
    }
}
#endif

/// Lets any page switch tabs (e.g. Home avatar → Profile).
private struct SelectTabKey: EnvironmentKey {
    static let defaultValue: (MainTabView.Tab) -> Void = { _ in }
}
extension EnvironmentValues {
    var selectTab: (MainTabView.Tab) -> Void {
        get { self[SelectTabKey.self] }
        set { self[SelectTabKey.self] = newValue }
    }
}
