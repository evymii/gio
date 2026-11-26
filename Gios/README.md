# Gios

iOS app for a social campus map: see friends on the map, discover spots, check in for XP, complete quests and climb the leaderboard. It talks to the **Gapi** backend.

SwiftUI · MapKit · CoreLocation · iOS 17+ · XcodeGen

## Run it

```bash
brew install xcodegen         # once
xcodegen generate             # rerun after adding/removing files
open Gios.xcodeproj           # pick an iPhone simulator → Cmd+R
```

1. Gapi is deployed at https://gio-wbqj.onrender.com — nothing to run locally. The first request after ~15 min idle takes up to a minute while Render wakes it.
2. Give the simulator a location on campus. Either run `xcrun simctl location booted set 37.3349,-122.0090`, or use **Features → Location → Apple** in the Simulator menu.
3. Log in with **Use demo account** (demo@gios.app / campus123), or sign up.

Debug and Release builds both talk to the deployed API (set in `project.yml`).

Debug-only launch flags for QA and screenshots: `-demoLogin` (signs in the demo account) and `-tab 0…3` (opens a tab).

## User flow

Splash → session restored from the Keychain → **Log in / Sign up** → tabs:

| Tab | What's there |
|---|---|
| **Home** | Level + XP, stats, nearby spots (check in), quests (claim), friends online, weekly rank → leaderboard |
| **Map** | Spots with check-in radius, friends sharing their location, you. Tap a spot to check in. Refreshes every 30 s. |
| **Friends** | Incoming requests (accept/decline), friends with online status, sent requests, search to add |
| **Profile** | Location sharing toggle (ghost mode), permission, check-in calendar, leaderboard, server status, log out |

## Structure

```
Gios/
  App/            GiosApp, AppEnvironment (shared services), RootView (flow), shared actions (check in, claim)
  Core/
    Auth/         SessionStore (who's logged in), TokenStore (tokens + refresh), Keychain
    Networking/   APIClient (data/error envelopes, auto token refresh), Endpoints (one function per API call)
    Location/     LocationService (permission, GPS), LocationSharer (throttled uploads: 30 s / 25 m)
    Theme/        design tokens: colors, spacing, fonts, spot styles
    Components/   Card, AvatarView, ProgressBar, SpotIcon, PrimaryButtonStyle
  Models/         Codable mirrors of Gapi responses
  Features/       Splash, Auth, Main (tabs), Dashboard, Map, Friends, Profile, Leaderboard
GiosTests/        APIClient tests: login, bearer token, refresh-and-retry, session expiry, errors, dashboard
```

**Where to apply your designs:** colors, fonts and spacing live in `Core/Theme/Theme.swift`, and reusable pieces in `Core/Components/`. Each screen is one file in `Features/`.
