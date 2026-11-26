import { Router } from 'express';
import { z } from 'zod';
import { requireAuth } from '../../middleware/auth.js';
import { validate } from '../../middleware/validate.js';
import { leaderboard } from './leaderboard.service.js';

const query = z.object({
  period: z.enum(['weekly', 'all_time']).default('weekly'),
  limit: z.coerce.number().int().min(1).max(100).default(20),
});

/** /api/v1/leaderboards — campus-wide XP rankings per period. */
export const leaderboardsRouter = Router();
leaderboardsRouter.use(requireAuth);

leaderboardsRouter.get('/', validate(query, 'query'), async (req, res) => {
  const q = res.locals.query as z.infer<typeof query>;
  res.json({ data: await leaderboard(req.userId, q.period, q.limit) });
});
