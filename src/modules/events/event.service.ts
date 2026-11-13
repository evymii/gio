import type { Types } from 'mongoose';
import { GameEvent } from './event.model.js';

/** Events running right now that apply to a region (or everywhere). */
export function activeEvents(region: Types.ObjectId | null = null, now = new Date()) {
  return GameEvent.find({
    startsAt: { $lte: now },
    endsAt: { $gt: now },
    $or: [{ region: null }, ...(region ? [{ region }] : [])],
  }).sort({ endsAt: 1 });
}

export async function xpMultiplier(region: Types.ObjectId | null, now = new Date()) {
  const events = await activeEvents(region, now);
  return events.reduce((m, e) => Math.max(m, e.xpMultiplier), 1);
}
