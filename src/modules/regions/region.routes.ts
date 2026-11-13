import { Router } from 'express';
import { z } from 'zod';
import { requireAuth } from '../../middleware/auth.js';
import { validate } from '../../middleware/validate.js';
import { Region } from './region.model.js';
import { regionAt } from './region.service.js';

type RegionLike = { _id: unknown; slug: string; name: string; area?: unknown };
export const toRegionDTO = (r: RegionLike) => ({
  id: String(r._id),
  slug: r.slug,
  name: r.name,
  // [[lng, lat], …] → [{lat, lng}, …] for map overlays
  boundary: ((r.area as { coordinates: number[][][] }).coordinates[0] ?? []).map(([lng, lat]) => ({ lat, lng })),
});

const atQuery = z.object({ lat: z.coerce.number().min(-90).max(90), lng: z.coerce.number().min(-180).max(180) });

/** /api/v1/regions — campus areas (polygons). */
export const regionsRouter = Router();
regionsRouter.use(requireAuth);

regionsRouter.get('/', async (_req, res) => {
  res.json({ data: (await Region.find().sort({ name: 1 })).map(toRegionDTO) });
});

/** Which region a point is in (or null). */
regionsRouter.get('/at', validate(atQuery, 'query'), async (_req, res) => {
  const r = await regionAt(res.locals.query);
  res.json({ data: r ? toRegionDTO(r) : null });
});
