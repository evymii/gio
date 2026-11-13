import { Router } from 'express';
import { z } from 'zod';
import { geohash, toPoint } from '../../lib/geo.js';
import { requireAuth } from '../../middleware/auth.js';
import { validate } from '../../middleware/validate.js';
import { ApiError } from '../../utils/ApiError.js';
import { acceptedFriendIds } from '../friends/friend.service.js';
import { lastLocationDTO, toPublicUserDTO } from '../users/user.dto.js';
import { User } from '../users/user.model.js';
import { UserLocation } from './userLocation.model.js';

const pointInput = z.object({
  lat: z.number().min(-90).max(90),
  lng: z.number().min(-180).max(180),
  accuracyMeters: z.number().min(0).max(5000).optional(),
  recordedAt: z.coerce.date().optional(),
});
const uploadSchema = z.object({ points: z.array(pointInput).min(1).max(50) });

/** A friend counts as "online" if their last update is this recent. */
export const ONLINE_WINDOW_MS = 15 * 60_000;
/** Friends whose location is older than this aren't shown on the map. */
const STALE_AFTER_MS = 24 * 60 * 60_000;

/** /api/v1/locations — share your location; see your friends'. */
export const locationsRouter = Router();
locationsRouter.use(requireAuth);

/**
 * Upload 1–50 points (the app batches them). The newest becomes your
 * `lastLocation`. Raw history is only stored while sharing is on, and expires
 * automatically after LOCATION_TTL_DAYS.
 */
locationsRouter.post('/', validate(uploadSchema), async (req, res) => {
  const me = await User.findById(req.userId);
  if (!me) throw ApiError.unauthorized();
  const now = Date.now();
  const points = (res.locals.body.points as z.infer<typeof pointInput>[])
    .map((p) => ({ ...p, recordedAt: p.recordedAt && p.recordedAt.getTime() <= now + 60_000 ? p.recordedAt : new Date(now) }))
    .sort((a, b) => a.recordedAt.getTime() - b.recordedAt.getTime());

  if (me.locationSharing !== 'off') {
    await UserLocation.insertMany(
      points.map((p) => ({
        user: me._id,
        point: toPoint(p),
        accuracyMeters: p.accuracyMeters ?? null,
        geohash: geohash(p),
        recordedAt: p.recordedAt,
      })),
    );
  }
  const newest = points[points.length - 1];
  if (!me.lastLocation || newest.recordedAt > me.lastLocation.recordedAt) {
    me.lastLocation = { point: toPoint(newest), accuracyMeters: newest.accuracyMeters, recordedAt: newest.recordedAt };
    await me.save();
  }
  res.status(201).json({ data: { accepted: points.length, stored: me.locationSharing !== 'off', lastLocation: lastLocationDTO(me) } });
});

/** Friends who share their location with you, with their last known position. */
locationsRouter.get('/friends', async (req, res) => {
  const ids = await acceptedFriendIds(req.userId);
  const friends = await User.find({
    _id: { $in: ids },
    locationSharing: 'friends',
    'lastLocation.recordedAt': { $gte: new Date(Date.now() - STALE_AFTER_MS) },
  });
  res.json({
    data: friends.map((f) => {
      const loc = lastLocationDTO(f)!;
      return { user: toPublicUserDTO(f), location: loc, online: Date.now() - Date.parse(loc.recordedAt) < ONLINE_WINDOW_MS };
    }),
  });
});
