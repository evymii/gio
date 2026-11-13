import { Router } from 'express';
import { z } from 'zod';
import { requireAuth } from '../../middleware/auth.js';
import { validate } from '../../middleware/validate.js';
import { checkIn, myCheckins } from './checkin.service.js';

const checkinSchema = z.object({
  spotId: z.string().regex(/^[a-f\d]{24}$/i, 'Invalid spot id'),
  lat: z.number().min(-90).max(90),
  lng: z.number().min(-180).max(180),
  accuracyMeters: z.number().min(0).max(5000).optional(),
});
const listQuery = z.object({ limit: z.coerce.number().int().min(1).max(100).default(20) });

/** /api/v1/checkins — check in at a spot; your history. */
export const checkinsRouter = Router();
checkinsRouter.use(requireAuth);

checkinsRouter.post('/', validate(checkinSchema), async (req, res) => {
  const result = await checkIn(req.userId, res.locals.body);
  res.status(result.checkin.verified ? 201 : 200).json({ data: result });
});

checkinsRouter.get('/', validate(listQuery, 'query'), async (req, res) => {
  res.json({ data: await myCheckins(req.userId, res.locals.query.limit) });
});
