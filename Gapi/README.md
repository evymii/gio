# Gapi

API for **Gios**, a social campus map: share your location with friends, discover campus spots, check in to earn XP, complete quests and climb the leaderboards.

Node 22 · Express 5 · TypeScript · MongoDB (Mongoose, geospatial `2dsphere` indexes) · zod · JWT auth

## Quick start

```bash
npm install
npm run dev:memory        # temporary in-memory database, auto-seeded — no setup needed
# or, with your Atlas database in .env:
npm run seed && npm run dev
```

The API runs at `http://localhost:8080`. Log in as **demo@gios.app / campus123**.

| Script | What it does |
|---|---|
| `npm run dev` | API with hot reload, using `MONGODB_URI` from `.env` |
| `npm run dev:memory` | API with a temporary in-memory MongoDB, seeded automatically |
| `npm run seed` | Creates every collection and index, updates the catalog and rebuilds the demo users' activity. Safe to rerun. |
| `npm run seed:reset` | Same as `seed`, but wipes the catalog (spots, quests) first. |
| `npm test` | 18 tests against an in-memory MongoDB |
| `npm run typecheck` / `npm run build` / `npm start` | Type-check, compile, run compiled code |

The seed only touches the demo accounts (`*@gios.app`). Real users and their data are never modified.

## Database

MongoDB with GeoJSON + `2dsphere` indexes, MongoDB's built-in equivalent of PostGIS. Points are stored as `{ type: "Point", coordinates: [lng, lat] }`, and the API returns plain `lat`/`lng`.

| Collection | Fields (design name → stored name) | Notes |
|---|---|---|
| `users` | id, name, avatar, level, xp, created_at → `createdAt`; + `email`, `passwordHash`, `locationSharing` (`friends`/`off`), `lastLocation` | `lastLocation.point` 2dsphere |
| `sessions` | user, tokenHash, expiresAt | one per login; TTL index deletes expired sessions |
| `user_locations` | user, lat/lng → `point`, accuracy_m → `accuracyMeters`, geohash, recorded_at → `recordedAt` | **TTL: deleted after `LOCATION_TTL_DAYS` (7)**; only stored while sharing is on |
| `spots` | name, type, lat/lng → `point`, geohash, radius_m → `radiusMeters`, reward_xp → `rewardXp`, active | 2dsphere for "nearby" |
| `checkins` | user, spot, lat/lng → `point`, distance_m → `distanceMeters`, verified, `xpAwarded`, created_at | distance measured by the server |
| `quests` / `user_quests` | title, goal `{type, target, spotType}`, `rewardXp` / user, quest, progress, status | goals: `checkins`, `unique_spots`, `spot_type` |
| `leaderboards` | user, period (`all_time` or `week:2026-W46`), score | updated on every XP gain |
| `friends` | user (requester), friend, status (`pending`/`accepted`) | unique pair |

## API (v1)

Every endpoint except `/health` and `/auth/*` needs `Authorization: Bearer <accessToken>`. Responses are `{ "data": … }` on success or `{ "error": { code, message, details? } }` on failure.

| Method & path | Purpose |
|---|---|
| `POST /auth/signup` `{name, email, password}` | Create an account. Returns `{user, accessToken, refreshToken, expiresIn}`. |
| `POST /auth/login` `{email, password}` | Log in. Same response as signup. |
| `POST /auth/refresh` `{refreshToken}` | Get new tokens. The old refresh token stops working. |
| `POST /auth/logout` `{refreshToken}` | End this session. |
| `GET /users/me` · `PATCH /users/me` `{name?, avatar?, locationSharing?}` | Your profile, including level progress. |
| `GET /users/search?q=` | Find people by name prefix or exact email. |
| `POST /locations` `{points:[{lat,lng,accuracyMeters?,recordedAt?}]}` | Share your location (1–50 points per call). |
| `GET /locations/friends` | Friends' last positions. Includes only friends who share, and only positions from the last 24 h. |
| `GET /friends` · `POST /friends/requests` `{userId}` · `POST /friends/:id/accept` · `DELETE /friends/:id` | Your friends and friend requests. |
| `GET /spots` · `GET /spots/nearby?lat&lng&radius` · `GET /spots/:id` | Spots. Nearby results include `distanceMeters`, `inRange` and `cooldownUntil`. |
| `POST /checkins` `{spotId, lat, lng, accuracyMeters?}` · `GET /checkins` | Check in (verified if within the spot's radius, with up to 50 m of GPS tolerance; 6 h cooldown per spot). See your history. |
| `GET /quests` · `POST /quests/:id/claim` | Quests with your progress. Claiming grants XP. |
| `GET /leaderboards?period=weekly\|all_time` | Campus-wide top players plus your rank. |
| `GET /dashboard?lat&lng` | Everything for the home screen in one call. |
| `GET /health` | API and database status. |

## Privacy rules
- Location is visible **only to accepted friends**, and only while `locationSharing` is `friends`. Setting it to `off` (ghost mode) hides you immediately and stops storing your history.
- Raw location history is deleted automatically after 7 days (TTL index).
- Passwords are hashed with bcrypt. Refresh tokens are stored only as SHA-256 hashes, and request bodies are never logged.

## Deploy (Atlas + Render)
1. **Atlas:** set Network Access to `0.0.0.0/0` and copy the connection string, with `/game` before the `?`.
2. Push this repo to GitHub.
3. **Render:** choose New → Blueprint → this repo. Paste `MONGODB_URI`; `JWT_SECRET` is generated for you.
4. Run the seed once against Atlas from your Mac (`npm run seed`), then open `https://<service>.onrender.com/health`.
