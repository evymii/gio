import { Types } from 'mongoose';
import { distanceMeters, fromPoint, toPoint, type LatLng } from '../../lib/geo.js';
import { ApiError } from '../../utils/ApiError.js';
import { recordCheckinProgress } from '../quests/quest.service.js';
import { toSpotDTO } from '../spots/spot.dto.js';
import { Spot } from '../spots/spot.model.js';
import { awardXp } from '../users/xp.service.js';
import { Checkin } from './checkin.model.js';

/** One verified check-in per spot per 6 hours. */
export const CHECKIN_COOLDOWN_MS = 6 * 60 * 60_000;
/** GPS accuracy we'll forgive on top of the spot radius. */
const MAX_ACCURACY_ALLOWANCE_M = 50;

export interface CheckinInput extends LatLng {
  spotId: string;
  accuracyMeters?: number;
}

/**
 * Check in at a spot. The server measures the distance itself (never trusts
 * the client's claim); within radius (+ some GPS slack) → verified + XP.
 * Unverified attempts are recorded too (useful for tuning radii / spotting cheats).
 */
export async function checkIn(userId: string, input: CheckinInput) {
  const spot = await Spot.findOne({ _id: input.spotId, active: true });
  if (!spot) throw ApiError.notFound('Spot not found');

  const me = new Types.ObjectId(userId);
  const at: LatLng = { lat: input.lat, lng: input.lng };
  const distance = distanceMeters(at, fromPoint(spot.point));
  const slack = Math.min(input.accuracyMeters ?? 0, MAX_ACCURACY_ALLOWANCE_M);
  const verified = distance <= spot.radiusMeters + slack;

  if (verified) {
    const recent = await Checkin.findOne({
      user: me, spot: spot._id, verified: true, createdAt: { $gte: new Date(Date.now() - CHECKIN_COOLDOWN_MS) },
    }).sort({ createdAt: -1 });
    if (recent) {
      const until = new Date(recent.createdAt.getTime() + CHECKIN_COOLDOWN_MS);
      throw ApiError.conflict('You already checked in here recently', 'COOLDOWN', { cooldownUntil: until.toISOString() });
    }
  }

  const xpAwarded = verified ? spot.rewardXp : 0;

  const checkin = await Checkin.create({
    user: me,
    spot: spot._id,
    point: toPoint(at),
    accuracyMeters: input.accuracyMeters ?? null,
    distanceMeters: Math.round(distance),
    verified,
    xpAwarded,
  });

  const result = {
    checkin: {
      id: String(checkin._id),
      spot: toSpotDTO(spot),
      distanceMeters: checkin.distanceMeters,
      verified,
      xpAwarded,
      createdAt: checkin.createdAt.toISOString(),
    },
    user: null as null | { xp: number; level: number; leveledUp: boolean },
    quests: [] as Awaited<ReturnType<typeof recordCheckinProgress>>,
    message: verified ? `+${xpAwarded} XP at ${spot.name}` : `Get closer — you're ${Math.round(distance)} m away (need ${spot.radiusMeters} m)`,
  };
  if (verified) {
    result.user = await awardXp(me, xpAwarded);
    result.quests = await recordCheckinProgress(me, { _id: spot._id, type: spot.type });
  }
  return result;
}

/** Your recent check-ins (verified only). */
export async function myCheckins(userId: string, limit = 20) {
  const rows = await Checkin.find({ user: userId, verified: true })
    .sort({ createdAt: -1 })
    .limit(limit)
    .populate<{ spot: Parameters<typeof toSpotDTO>[0] }>('spot');
  return rows.filter((r) => r.spot).map((r) => ({
    id: String(r._id),
    spot: toSpotDTO(r.spot),
    xpAwarded: r.xpAwarded,
    distanceMeters: r.distanceMeters,
    createdAt: r.createdAt.toISOString(),
  }));
}
