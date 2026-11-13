import SwiftUI

struct MainTabView: View {
    @State private var tab = MainTabView.initialTab

    var body: some View {
        #if DEBUG
        if let screen = Self.debugScreen {
            NavigationStack { screen }
        } else { tabs }
        #else
        tabs
        #endif
    }

    #if DEBUG
    /// DEBUG: `-open quests|rewards|history|events|spots|edit|leaderboard` opens one page directly (screenshots/QA).
    @ViewBuilder private static var debugScreen: (some View)? {
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-open"), i + 1 < args.count {
            switch args[i + 1] {
            case "quests": QuestsView()
            case "rewards": RewardsView()
            case "history": CheckinHistoryView()
            case "events": EventsView()
            case "spots": SpotsListView()
            case "edit": EditProfileView()
            default: LeaderboardView()
            }
        }
    }
    #endif

    private var tabs: some View {
        TabView(selection: $tab) {
            NavigationStack { DashboardView() }
                .tabItem { Label("Home", systemImage: "house.fill") }.tag(0)
            NavigationStack { CampusMapView() }
                .tabItem { Label("Map", systemImage: "map.fill") }.tag(1)
            NavigationStack { FriendsView() }
                .tabItem { Label("Friends", systemImage: "person.2.fill") }.tag(2)
            NavigationStack { ProfileView() }
                .tabItem { Label("Profile", systemImage: "person.crop.circle.fill") }.tag(3)
        }
    }

    /// DEBUG: `-tab 1` opens the Map tab (screenshots/QA).
    private static var initialTab: Int {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-tab"), i + 1 < args.count, let n = Int(args[i + 1]) { return n }
        #endif
        return 0
    }
}
