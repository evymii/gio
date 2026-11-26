import { Schema, model } from 'mongoose';

export const FRIEND_STATUSES = ['pending', 'accepted'] as const;

/** friends — user_id (requester), friend_id (addressee), status. One row per pair. */
const friendshipSchema = new Schema(
  {
    user: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    friend: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    status: { type: String, enum: FRIEND_STATUSES, default: 'pending' },
    acceptedAt: { type: Date, default: null },
  },
  { timestamps: true, collection: 'friends' },
);

friendshipSchema.index({ user: 1, friend: 1 }, { unique: true });
friendshipSchema.index({ friend: 1, status: 1 });

export const Friendship = model('Friendship', friendshipSchema);
