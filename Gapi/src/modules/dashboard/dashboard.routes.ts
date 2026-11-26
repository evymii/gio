import { Router } from 'express';
import { Types } from 'mongoose';
import { z } from 'zod';
import { distanceMeters, fromPoint, type LatLng } from '../../lib/geo.js';
import { startOfIsoWeek } from '../../lib/periods.js';
import { requireAuth } from '../../middleware/auth.js';
import { validate } from '../../middleware/validate.js';
import { ApiError } from '../../utils/ApiError.js';
import { Checkin } from '../checkins/checkin.model.js';
import { acceptedFriendIds } from '../friends/friend.service.js';
import { leaderboard } from '../leaderboards/leaderboard.service.js';
import { ONLINE_WINDOW_MS } from '../locations/location.routes.js';
import { questsFor } from '../quests/quest.service.js';
import { nearbySpots } from '../spots/spot.service.js';
import { toMeDTO, toPublicUserDTO } from '../users/user.dto.js';
import { User } from '../users/user.model.js';

const query = z.object({
  lat: z.coerce.number().min(-90).max(90).optional(),
  lng: z.coerce.number().min(-180).max(180).optional(),
});

/**
 * /api/v1/dashboard — everything the home screen needs in one request:
 * profile + level, stats, nearby spots, quests, friends online, weekly rank.
 * Pass ?lat=&lng= for the current position (falls back to your last shared location).
 */
export const dashboardRouter = Router();
dashboardRouter.use(requireAuth);

dashboardRouter.get('/', validate(query, 'query'), async (req, res) => {
  const me = await User.findById(req.userId);
  if (!me) throw ApiError.unauthorized();
  const q = res.locals.query as z.infer<typeof query>;
  const here: LatLng | null =
    q.lat !== undefined && q.lng !== undefined ? { lat: q.lat, lng: q.lng } : me.lastLocation?.point ? fromPoint(me.lastLocation.point) : null;

  const myId = new Types.ObjectId(req.userId);
  const friendIds = await acceptedFriendIds(req.userId);

  const [checkinsTotal, checkinsThisWeek, uniqueSpots, friends, spots, quests, weekly] = await Promise.all([
    Checkin.countDocuments({ user: myId, verified: true }),
    Checkin.countDocuments({ user: myId, verified: true, createdAt: { $gte: startOfIsoWeek() } }),
    Checkin.distinct('spot', { user: myId, verified: true }).then((s) => s.length),
    User.find({ _id: { $in: friendIds } }),
    here ? nearbySpots(req.userId, here, 2000, 5) : Promise.resolve([]),
    questsFor(req.userId),
    leaderboard(req.userId, 'weekly', 3),
  ]);

  const now = Date.now();
  const online = friends
    .filter((f) => f.locationSharing === 'friends' && f.lastLocation && now - f.lastLocation.recordedAt.getTime() < ONLINE_WINDOW_MS)
    .map((f) => ({
      user: toPublicUserDTO(f),
      lastSeenAt: f.lastLocation!.recordedAt.toISOString(),
      distanceMeters: here ? Math.round(distanceMeters(here, fromPoint(f.lastLocation!.point))) : null,
    }))
    .sort((a, b) => (a.distanceMeters ?? Infinity) - (b.distanceMeters ?? Infinity));

  // Claimable first, then the ones you've made the most progress on.
  const questOrder = (s: string) => (s === 'completed' ? 0 : s === 'in_progress' ? 1 : 2);
  const highlighted = quests
    .filter((x) => x.status !== 'claimed')
    .sort((a, b) => questOrder(a.status) - questOrder(b.status) || b.progress / b.goal.target - a.progress / a.goal.target)
    .slice(0, 3);

  res.json({
    data: {
      user: toMeDTO(me),
      position: here,
      stats: { checkinsTotal, checkinsThisWeek, uniqueSpots, friends: friends.length },
      nearbySpots: spots,
      quests: highlighted,
      friendsOnline: { count: online.length, total: friends.length, users: online.slice(0, 5) },
      leaderboard: { period: 'weekly', rank: weekly.me.rank, score: weekly.me.score, top: weekly.entries },
    },
  });
});
