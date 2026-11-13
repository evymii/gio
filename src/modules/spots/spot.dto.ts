import { fromPoint } from '../../lib/geo.js';

type SpotLike = {
  _id: unknown; slug: string; name: string; type: string; description?: string | null;
  point: { coordinates: number[] }; geohash: string; radiusMeters: number; rewardXp: number; active: boolean;
};

export function toSpotDTO(s: SpotLike) {
  return {
    id: String(s._id),
    slug: s.slug,
    name: s.name,
    type: s.type,
    description: s.description ?? '',
    ...fromPoint(s.point),
    geohash: s.geohash,
    radiusMeters: s.radiusMeters,
    rewardXp: s.rewardXp,
    active: s.active,
  };
}
