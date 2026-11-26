import { Types } from 'mongoose';
import { toPoint, type LatLng } from '../../lib/geo.js';
import { Checkin } from '../checkins/checkin.model.js';
import { CHECKIN_COOLDOWN_MS } from '../checkins/checkin.service.js';
import { toSpotDTO } from './spot.dto.js';
import { Spot } from './spot.model.js';

/** Active spots near a point, nearest first, with your check-in availability. */
export async function nearbySpots(userId: string, at: LatLng, radiusMeters = 1500, limit = 30) {
  const docs = await Spot.aggregate([
    {
      $geoNear: {
        near: toPoint(at),
        distanceField: 'distanceMeters',
        maxDistance: radiusMeters,
        query: { active: true },
        spherical: true,
      },
    },
    { $limit: limit },
  ]);
  const since = new Date(Date.now() - CHECKIN_COOLDOWN_MS);
  const recent = await Checkin.find({
    user: new Types.ObjectId(userId),
    spot: { $in: docs.map((d) => d._id) },
    verified: true,
    createdAt: { $gte: since },
  }).lean();
  const lastBySpot = new Map<string, Date>();
  for (const c of recent) {
    const k = String(c.spot);
    if (!lastBySpot.has(k) || c.createdAt > lastBySpot.get(k)!) lastBySpot.set(k, c.createdAt);
  }
  return docs.map((d) => {
    const last = lastBySpot.get(String(d._id));
    return {
      ...toSpotDTO(d),
      distanceMeters: Math.round(d.distanceMeters),
      inRange: d.distanceMeters <= d.radiusMeters,
      cooldownUntil: last ? new Date(last.getTime() + CHECKIN_COOLDOWN_MS).toISOString() : null,
    };
  });
}
