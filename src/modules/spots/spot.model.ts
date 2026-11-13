import { Schema, model } from 'mongoose';
import { pointSchema } from '../../db/pointSchema.js';

export const SPOT_TYPES = ['library', 'cafe', 'study', 'sports', 'landmark', 'food', 'event'] as const;

/** spots — id, name, type, lat, lng, geohash, radius_m, reward_xp, active. */
const spotSchema = new Schema(
  {
    slug: { type: String, required: true, unique: true },
    name: { type: String, required: true, trim: true },
    type: { type: String, enum: SPOT_TYPES, required: true },
    description: { type: String, default: '' },
    point: { type: pointSchema, required: true },
    geohash: { type: String, required: true, index: true },
    radiusMeters: { type: Number, required: true, min: 10, max: 500 },
    rewardXp: { type: Number, required: true, min: 0 },
    active: { type: Boolean, default: true },
    region: { type: Schema.Types.ObjectId, ref: 'Region', default: null },
  },
  { timestamps: true, collection: 'spots' },
);

spotSchema.index({ point: '2dsphere' });

export const Spot = model('Spot', spotSchema);
