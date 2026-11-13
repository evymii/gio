import { Router } from 'express';
import { z } from 'zod';
import { requireAuth } from '../../middleware/auth.js';
import { validate } from '../../middleware/validate.js';
import { ApiError } from '../../utils/ApiError.js';
import { Region } from '../regions/region.model.js';
import { leaderboard } from './leaderboard.service.js';

const query = z.object({
  period: z.enum(['weekly', 'all_time']).default('weekly'),
  region: z.string().optional(), // region slug; omit for campus-wide
  limit: z.coerce.number().int().min(1).max(100).default(20),
});

/** /api/v1/leaderboards — XP rankings per region and period. */
export const leaderboardsRouter = Router();
leaderboardsRouter.use(requireAuth);

leaderboardsRouter.get('/', validate(query, 'query'), async (req, res) => {
  const q = res.locals.query as z.infer<typeof query>;
  let regionId = null;
  if (q.region) {
    const r = await Region.findOne({ slug: q.region });
    if (!r) throw ApiError.notFound('Region not found');
    regionId = r._id;
  }
  res.json({ data: await leaderboard(req.userId, q.period, regionId, q.limit) });
});
