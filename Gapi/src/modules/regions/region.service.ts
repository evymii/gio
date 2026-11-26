import { toPoint, type LatLng } from '../../lib/geo.js';
import { Region } from './region.model.js';

/** The region containing a point, if any (MongoDB $geoIntersects on the polygon). */
export function regionAt(at: LatLng) {
  return Region.findOne({ area: { $geoIntersects: { $geometry: toPoint(at) } } });
}
