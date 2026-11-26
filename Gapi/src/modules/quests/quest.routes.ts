import { Router } from 'express';
import { z } from 'zod';
import { requireAuth } from '../../middleware/auth.js';
import { validate } from '../../middleware/validate.js';
import { claimQuest, questsFor } from './quest.service.js';

const idParams = z.object({ id: z.string().regex(/^[a-f\d]{24}$/i, 'Invalid id') });

/** /api/v1/quests — goals with progress; claim when complete. */
export const questsRouter = Router();
questsRouter.use(requireAuth);

questsRouter.get('/', async (req, res) => {
  res.json({ data: await questsFor(req.userId) });
});

questsRouter.post('/:id/claim', validate(idParams, 'params'), async (req, res) => {
  res.json({ data: await claimQuest(req.userId, res.locals.params.id) });
});
