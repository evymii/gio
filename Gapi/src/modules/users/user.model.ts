import { Schema, model, type HydratedDocument, type InferSchemaType } from 'mongoose';
import { pointSchema } from '../../db/pointSchema.js';

export const SHARING_MODES = ['friends', 'off'] as const;

/** users — id, name, avatar, level, xp, created_at (+ login + sharing fields).
 * Login is either phone (Firebase Auth) or email + password (demo / seed accounts). */
const userSchema = new Schema(
  {
    name: { type: String, required: true, trim: true, minlength: 2, maxlength: 30 },
    email: { type: String, lowercase: true, trim: true },
    passwordHash: { type: String, select: false },
    /** E.164, e.g. +97699999999 — set by phone sign-in. */
    phone: { type: String, trim: true },
    firebaseUid: { type: String },
    avatar: { type: String, default: 'avatar-1' },
    level: { type: Number, default: 1, min: 1 },
    xp: { type: Number, default: 0, min: 0 },
    /** "friends" = accepted friends see you on the map; "off" = ghost mode. */
    locationSharing: { type: String, enum: SHARING_MODES, default: 'friends' },
    /** Latest known position (denormalised from user_locations for fast map queries). */
    lastLocation: {
      type: new Schema(
        { point: { type: pointSchema, required: true }, accuracyMeters: Number, recordedAt: { type: Date, required: true } },
        { _id: false },
      ),
      default: undefined,
    },
  },
  { timestamps: true, collection: 'users' },
);

userSchema.index({ 'lastLocation.point': '2dsphere' }, { sparse: true });
// Partial unique indexes: each login field is unique only among users that have it.
userSchema.index({ email: 1 }, { unique: true, partialFilterExpression: { email: { $type: 'string' } } });
userSchema.index({ phone: 1 }, { unique: true, partialFilterExpression: { phone: { $type: 'string' } } });
userSchema.index({ firebaseUid: 1 }, { unique: true, partialFilterExpression: { firebaseUid: { $type: 'string' } } });

export type UserDoc = HydratedDocument<InferSchemaType<typeof userSchema>>;
export const User = model('User', userSchema);
