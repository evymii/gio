import { Router } from 'express';
import { z } from 'zod';
import { requireAuth } from '../../middleware/auth.js';
import { validate } from '../../middleware/validate.js';
import { ApiError } from '../../utils/ApiError.js';
import { toSpotDTO } from './spot.dto.js';
import { SPOT_TYPES, Spot } from './spot.model.js';
import { nearbySpots } from './spot.service.js';

const nearbyQuery = z.object({
  lat: z.coerce.number().min(-90).max(90),
  lng: z.coerce.number().min(-180).max(180),
  radius: z.coerce.number().int().min(50).max(20_000).default(1500),
  limit: z.coerce.number().int().min(1).max(100).default(30),
});
const listQuery = z.object({ type: z.enum(SPOT_TYPES).optional() });

/** /api/v1/spots — places on campus you can check in at. */
export const spotsRouter = Router();
spotsRouter.use(requireAuth);

spotsRouter.get('/', validate(listQuery, 'query'), async (_req, res) => {
  const q = res.locals.query as z.infer<typeof listQuery>;
  const docs = await Spot.find({ active: true, ...(q.type ? { type: q.type } : {}) }).sort({ name: 1 });
  res.json({ data: docs.map(toSpotDTO) });
});

spotsRouter.get('/nearby', validate(nearbyQuery, 'query'), async (req, res) => {
  const q = res.locals.query as z.infer<typeof nearbyQuery>;
  res.json({ data: await nearbySpots(req.userId, q, q.radius, q.limit) });
});

spotsRouter.get('/:id', async (req, res) => {
  const doc = /^[a-f\d]{24}$/i.test(req.params.id) ? await Spot.findById(req.params.id) : await Spot.findOne({ slug: req.params.id });
  if (!doc) throw ApiError.notFound('Spot not found');
  res.json({ data: toSpotDTO(doc) });
});
