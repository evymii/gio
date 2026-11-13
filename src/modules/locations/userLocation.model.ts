import { Schema, model } from 'mongoose';
import { pointSchema } from '../../db/pointSchema.js';
import { env } from '../../config/env.js';

/**
 * user_locations — id, user_id, lat, lng, accuracy_m, geohash, recorded_at.
 * Raw history is short-lived: a TTL index deletes points after LOCATION_TTL_DAYS.
 */
const userLocationSchema = new Schema(
  {
    user: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    point: { type: pointSchema, required: true },
    accuracyMeters: { type: Number, min: 0, default: null },
    geohash: { type: String, required: true, index: true },
    recordedAt: { type: Date, required: true },
  },
  { collection: 'user_locations' },
);

userLocationSchema.index({ point: '2dsphere' });
userLocationSchema.index({ user: 1, recordedAt: -1 });
userLocationSchema.index({ recordedAt: 1 }, { expireAfterSeconds: env.LOCATION_TTL_DAYS * 86_400 });

export const UserLocation = model('UserLocation', userLocationSchema);
