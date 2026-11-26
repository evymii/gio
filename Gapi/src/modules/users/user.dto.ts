import { fromPoint } from '../../lib/geo.js';
import { levelProgress } from '../../lib/levels.js';
import type { UserDoc } from './user.model.js';

/** What the owner sees about themselves. */
export function toMeDTO(u: UserDoc) {
  const lp = levelProgress(u.xp);
  return {
    id: String(u._id),
    name: u.name,
    email: u.email,
    avatar: u.avatar,
    level: lp.level,
    xp: u.xp,
    levelStartXp: lp.levelStartXp,
    nextLevelXp: lp.nextLevelXp,
    locationSharing: u.locationSharing,
    createdAt: u.createdAt.toISOString(),
  };
}

/** What other people see (no email, no location). */
export function toPublicUserDTO(u: Pick<UserDoc, '_id' | 'name' | 'avatar' | 'xp'>) {
  return { id: String(u._id), name: u.name, avatar: u.avatar, level: levelProgress(u.xp).level };
}

export function lastLocationDTO(u: UserDoc) {
  if (!u.lastLocation?.point) return null;
  return {
    ...fromPoint(u.lastLocation.point),
    accuracyMeters: u.lastLocation.accuracyMeters ?? null,
    recordedAt: u.lastLocation.recordedAt.toISOString(),
  };
}
