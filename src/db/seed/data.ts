/**
 * Starter content. Positions are offsets in meters (north, east) from the seed
 * centre (SEED_LAT/SEED_LNG; defaults to the iOS Simulator's default location),
 * so the whole campus can be moved anywhere by changing two env vars.
 */

export const SEED_EMAIL_DOMAIN = 'gios.app';

/** Squares (north/east offsets). The border sits 20 m south of the centre so the Main Gate is clearly North Campus. */
export const REGION_BORDER_NORTH = -20;
export const regions = [
  { slug: 'north-campus', name: 'North Campus', center: { north: 240, east: 0 }, halfSize: 260 }, // −20 … 500 m
  { slug: 'south-campus', name: 'South Campus', center: { north: -260, east: 0 }, halfSize: 240 }, // −500 … −20 m
];

export const spots = [
  { slug: 'main-gate', name: 'Main Gate', type: 'landmark', north: 20, east: 0, radiusMeters: 60, rewardXp: 20, description: 'Where every campus day begins.' },
  { slug: 'central-library', name: 'Central Library', type: 'library', north: 150, east: -120, radiusMeters: 50, rewardXp: 40, description: 'Five floors of quiet — and the best window seats.' },
  { slug: 'library-annex', name: 'Library Annex', type: 'library', north: -300, east: -380, radiusMeters: 40, rewardXp: 35, description: 'Late-night study rooms, open 24/7 in exam season.' },
  { slug: 'corner-cafe', name: 'Corner Café', type: 'cafe', north: -90, east: 110, radiusMeters: 40, rewardXp: 25, description: 'Flat whites and group projects.' },
  { slug: 'garden-cafe', name: 'Garden Café', type: 'cafe', north: 330, east: 200, radiusMeters: 40, rewardXp: 25, description: 'Tea under the trees.' },
  { slug: 'study-hall', name: 'Study Hall', type: 'study', north: 220, east: 160, radiusMeters: 50, rewardXp: 30, description: 'Long tables, plenty of plugs.' },
  { slug: 'science-building', name: 'Science Building', type: 'study', north: -180, east: 300, radiusMeters: 50, rewardXp: 30, description: 'Labs, lecture rooms and a vending machine that always works.' },
  { slug: 'sports-field', name: 'Sports Field', type: 'sports', north: -260, east: -200, radiusMeters: 80, rewardXp: 35, description: 'Football, frisbee and sunset runs.' },
  { slug: 'gym', name: 'Campus Gym', type: 'sports', north: 120, east: 380, radiusMeters: 50, rewardXp: 35, description: 'Weights, courts and a climbing wall.' },
  { slug: 'student-union', name: 'Student Union', type: 'food', north: 60, east: 260, radiusMeters: 50, rewardXp: 25, description: 'Lunch, clubs and the noticeboard.' },
  { slug: 'clock-tower', name: 'Old Clock Tower', type: 'landmark', north: 400, east: 50, radiusMeters: 40, rewardXp: 45, description: 'The oldest building on campus.' },
  { slug: 'night-market', name: 'Night Market Square', type: 'event', north: -60, east: -330, radiusMeters: 60, rewardXp: 50, description: 'Food stalls every Friday night.' },
] as const;

export const rewards = [
  { slug: 'newcomer-badge', name: 'Newcomer', type: 'badge', value: 'newcomer', icon: 'figure.walk', description: 'Made your first check-in.' },
  { slug: 'explorer-badge', name: 'Explorer', type: 'badge', value: 'explorer', icon: 'map.fill', description: 'Visited five different spots.' },
  { slug: 'bookworm-title', name: 'Bookworm', type: 'title', value: 'Bookworm', icon: 'books.vertical.fill', description: 'A title for library regulars.' },
  { slug: 'cafe-avatar', name: 'Café Regular', type: 'avatar', value: 'avatar-cafe', icon: 'cup.and.saucer.fill', description: 'A coffee-themed avatar.' },
  { slug: 'xp-boost', name: 'XP Boost', type: 'boost', value: 'xp_x2_1h', icon: 'bolt.fill', description: 'Double XP for one hour.' },
  { slug: 'athlete-badge', name: 'Athlete', type: 'badge', value: 'athlete', icon: 'figure.run', description: 'Warmed up at the sports spots.' },
] as const;

export const quests = [
  { slug: 'first-steps', title: 'First Steps', description: 'Check in anywhere on campus.', goal: { type: 'checkins', target: 1 }, rewardXp: 50, reward: 'newcomer-badge' },
  { slug: 'coffee-run', title: 'Coffee Run', description: 'Check in at 2 cafés.', goal: { type: 'spot_type', target: 2, spotType: 'cafe' }, rewardXp: 80, reward: 'cafe-avatar' },
  { slug: 'warm-up', title: 'Warm Up', description: 'Check in at sports spots twice.', goal: { type: 'spot_type', target: 2, spotType: 'sports' }, rewardXp: 100, reward: 'athlete-badge' },
  { slug: 'bookworm', title: 'Bookworm', description: 'Check in at libraries 3 times.', goal: { type: 'spot_type', target: 3, spotType: 'library' }, rewardXp: 150, reward: 'bookworm-title' },
  { slug: 'campus-explorer', title: 'Campus Explorer', description: 'Visit 5 different spots.', goal: { type: 'unique_spots', target: 5 }, rewardXp: 200, reward: 'explorer-badge' },
  { slug: 'regular', title: 'Campus Regular', description: 'Make 10 check-ins.', goal: { type: 'checkins', target: 10 }, rewardXp: 300, reward: 'xp-boost' },
] as const;

/** Relative to seed time, so there's always an active event. */
export const events = [
  { slug: 'welcome-week', title: 'Welcome Week', description: 'Double XP on every check-in.', region: null, startsInDays: -2, durationDays: 14, xpMultiplier: 2 },
  { slug: 'night-market-weekend', title: 'Night Market Weekend', description: '1.5× XP across South Campus.', region: 'south-campus', startsInDays: 5, durationDays: 2, xpMultiplier: 1.5 },
] as const;

/** Demo accounts (password = SEED_PASSWORD). Log in as demo@gios.app. */
export const users = [
  { key: 'demo', name: 'Demo Student', avatar: 'avatar-1', sharing: 'friends', at: null },
  { key: 'mio', name: 'Mio', avatar: 'avatar-2', sharing: 'friends', at: { spot: 'corner-cafe', minutesAgo: 2 } },
  { key: 'ana', name: 'Ana', avatar: 'avatar-3', sharing: 'friends', at: { spot: 'central-library', minutesAgo: 6 } },
  { key: 'kai', name: 'Kai', avatar: 'avatar-4', sharing: 'friends', at: { spot: 'sports-field', minutesAgo: 45 } },
  { key: 'rin', name: 'Rin', avatar: 'avatar-5', sharing: 'friends', at: { spot: 'study-hall', minutesAgo: 3 } },
  { key: 'leo', name: 'Leo', avatar: 'avatar-6', sharing: 'friends', at: { spot: 'student-union', minutesAgo: 10 } },
  { key: 'sora', name: 'Sora', avatar: 'avatar-7', sharing: 'off', at: { spot: 'gym', minutesAgo: 4 } },
] as const;

export type UserKey = (typeof users)[number]['key'];

/** [requester, addressee, status] */
export const friendships: [UserKey, UserKey, 'accepted' | 'pending'][] = [
  ['demo', 'mio', 'accepted'],
  ['ana', 'demo', 'accepted'],
  ['demo', 'kai', 'accepted'],
  ['sora', 'demo', 'accepted'],
  ['leo', 'demo', 'pending'], // incoming request for the demo user
  ['demo', 'rin', 'pending'], // outgoing request
  ['mio', 'ana', 'accepted'],
  ['rin', 'kai', 'accepted'],
];

/** Check-in history: [user, spot, daysAgo, hour of day]. Quests, XP and leaderboards are derived from this. */
export const checkins: [UserKey, string, number, number][] = [
  ['demo', 'main-gate', 3, 9], ['demo', 'corner-cafe', 2, 10], ['demo', 'garden-cafe', 1, 15], ['demo', 'central-library', 1, 11],
  ['mio', 'corner-cafe', 6, 9], ['mio', 'central-library', 5, 13], ['mio', 'study-hall', 4, 10], ['mio', 'clock-tower', 3, 17],
  ['mio', 'library-annex', 2, 21], ['mio', 'central-library', 1, 12], ['mio', 'garden-cafe', 0, 8],
  ['ana', 'central-library', 6, 10], ['ana', 'library-annex', 4, 20], ['ana', 'central-library', 2, 14], ['ana', 'study-hall', 1, 9],
  ['kai', 'sports-field', 5, 7], ['kai', 'gym', 4, 18], ['kai', 'sports-field', 1, 7], ['kai', 'student-union', 0, 12],
  ['rin', 'night-market', 6, 19], ['rin', 'science-building', 5, 11], ['rin', 'gym', 3, 16], ['rin', 'clock-tower', 2, 18],
  ['rin', 'corner-cafe', 2, 9], ['rin', 'main-gate', 1, 8], ['rin', 'student-union', 0, 13],
  ['leo', 'student-union', 3, 12], ['leo', 'main-gate', 0, 9],
  ['sora', 'gym', 2, 17], ['sora', 'garden-cafe', 1, 10],
];

/** Completed quests the demo user has NOT claimed yet (so the dashboard has something to claim). */
export const unclaimedForDemo = ['coffee-run'];
