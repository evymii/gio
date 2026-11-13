import { Schema, model } from 'mongoose';

/** events — id, region_id, starts_at, ends_at (+ title, XP multiplier). */
const eventSchema = new Schema(
  {
    slug: { type: String, required: true, unique: true },
    title: { type: String, required: true },
    description: { type: String, default: '' },
    region: { type: Schema.Types.ObjectId, ref: 'Region', default: null }, // null = everywhere
    startsAt: { type: Date, required: true },
    endsAt: { type: Date, required: true },
    xpMultiplier: { type: Number, default: 1, min: 1, max: 5 },
  },
  { timestamps: true, collection: 'events' },
);

eventSchema.index({ region: 1, startsAt: 1, endsAt: 1 });

export const GameEvent = model('GameEvent', eventSchema);
