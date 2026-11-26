/** Geo helpers. MongoDB stores points as GeoJSON: coordinates are [lng, lat]. */

export interface LatLng {
  lat: number;
  lng: number;
}

export interface GeoPoint {
  type: 'Point';
  coordinates: [number, number]; // [lng, lat]
}

export const toPoint = ({ lat, lng }: LatLng): GeoPoint => ({ type: 'Point', coordinates: [lng, lat] });

export const fromPoint = (p: { coordinates: number[] }): LatLng => ({ lat: p.coordinates[1], lng: p.coordinates[0] });

/** Great-circle distance in meters (haversine). */
export function distanceMeters(a: LatLng, b: LatLng): number {
  const R = 6_371_000;
  const toRad = (d: number) => (d * Math.PI) / 180;
  const dLat = toRad(b.lat - a.lat);
  const dLng = toRad(b.lng - a.lng);
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(toRad(a.lat)) * Math.cos(toRad(b.lat)) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.min(1, Math.sqrt(h)));
}

/** Moves a point by meters north/east (good enough for campus-scale offsets). */
export function offsetMeters(origin: LatLng, north: number, east: number): LatLng {
  const dLat = north / 111_320;
  const dLng = east / (111_320 * Math.cos((origin.lat * Math.PI) / 180));
  return { lat: origin.lat + dLat, lng: origin.lng + dLng };
}

const BASE32 = '0123456789bcdefghjkmnpqrstuvwxyz';

/** Standard geohash encoding (precision 7 ≈ 153 m × 153 m cells). */
export function geohash({ lat, lng }: LatLng, precision = 7): string {
  let latMin = -90, latMax = 90, lngMin = -180, lngMax = 180;
  let hash = '', bit = 0, ch = 0, even = true;
  while (hash.length < precision) {
    if (even) {
      const mid = (lngMin + lngMax) / 2;
      if (lng >= mid) { ch = (ch << 1) | 1; lngMin = mid; } else { ch <<= 1; lngMax = mid; }
    } else {
      const mid = (latMin + latMax) / 2;
      if (lat >= mid) { ch = (ch << 1) | 1; latMin = mid; } else { ch <<= 1; latMax = mid; }
    }
    even = !even;
    if (++bit === 5) { hash += BASE32[ch]; bit = 0; ch = 0; }
  }
  return hash;
}
