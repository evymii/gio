import { Schema, model } from 'mongoose';
import { pointSchema } from '../../db/pointSchema.js';

/** checkins — id, user_id, spot_id, lat, lng, distance_m, verified, created_at. */
const checkinSchema = new Schema(
  {
    user: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    spot: { type: Schema.Types.ObjectId, ref: 'Spot', required: true },
    point: { type: pointSchema, required: true },
    accuracyMeters: { type: Number, default: null },
    distanceMeters: { type: Number, required: true },
    verified: { type: Boolean, required: true },
    xpAwarded: { type: Number, default: 0 },
  },
  { timestamps: true, collection: 'checkins' },
);

checkinSchema.index({ user: 1, spot: 1, createdAt: -1 });
checkinSchema.index({ user: 1, createdAt: -1 });

export const Checkin = model('Checkin', checkinSchema);
