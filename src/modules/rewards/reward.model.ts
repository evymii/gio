import { Schema, model } from 'mongoose';

export const REWARD_TYPES = ['badge', 'title', 'avatar', 'boost'] as const;

/** rewards — id, type, value (+ name, description, icon). */
const rewardSchema = new Schema(
  {
    slug: { type: String, required: true, unique: true },
    name: { type: String, required: true },
    type: { type: String, enum: REWARD_TYPES, required: true },
    value: { type: String, required: true }, // e.g. badge id, title text, avatar id, "xp_x2_1h"
    description: { type: String, default: '' },
    icon: { type: String, default: 'star' }, // SF Symbol name for the app
  },
  { timestamps: true, collection: 'rewards' },
);

export const Reward = model('Reward', rewardSchema);

/** inventory — user_id, reward_id, qty, claimed_at. */
const inventorySchema = new Schema(
  {
    user: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    reward: { type: Schema.Types.ObjectId, ref: 'Reward', required: true },
    qty: { type: Number, default: 1, min: 0 },
    claimedAt: { type: Date, default: () => new Date() },
  },
  { timestamps: true, collection: 'inventory' },
);

inventorySchema.index({ user: 1, reward: 1 }, { unique: true });

export const InventoryItem = model('InventoryItem', inventorySchema);
