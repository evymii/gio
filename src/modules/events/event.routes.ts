import { Router } from 'express';
import { requireAuth } from '../../middleware/auth.js';
import { GameEvent } from './event.model.js';

type EventLike = { _id: unknown; slug: string; title: string; description?: string | null; region?: unknown; startsAt: Date; endsAt: Date; xpMultiplier: number };

export function toEventDTO(e: EventLike, now = new Date()) {
  return {
    id: String(e._id),
    slug: e.slug,
    title: e.title,
    description: e.description ?? '',
    regionId: e.region ? String(e.region) : null,
    startsAt: e.startsAt.toISOString(),
    endsAt: e.endsAt.toISOString(),
    xpMultiplier: e.xpMultiplier,
    isActive: e.startsAt <= now && e.endsAt > now,
  };
}

/** /api/v1/events — current and upcoming events. */
export const eventsRouter = Router();
eventsRouter.use(requireAuth);

eventsRouter.get('/', async (_req, res) => {
  const now = new Date();
  const docs = await GameEvent.find({ endsAt: { $gt: now } }).sort({ startsAt: 1 });
  res.json({ data: docs.map((e) => toEventDTO(e, now)) });
});
