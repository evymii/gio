import { Schema, model } from 'mongoose';
import { SPOT_TYPES } from '../spots/spot.model.js';

export const GOAL_TYPES = ['checkins', 'unique_spots', 'spot_type'] as const;
export const USER_QUEST_STATUSES = ['in_progress', 'completed', 'claimed'] as const;

const goalSchema = new Schema(
  {
    type: { type: String, enum: GOAL_TYPES, required: true },
    target: { type: Number, required: true, min: 1 },
    spotType: { type: String, enum: [...SPOT_TYPES, null], default: null },
  },
  { _id: false },
);

/** quests — id, title, goal, reward. */
const questSchema = new Schema(
  {
    slug: { type: String, required: true, unique: true },
    title: { type: String, required: true },
    description: { type: String, default: '' },
    goal: { type: goalSchema, required: true },
    rewardXp: { type: Number, default: 0, min: 0 },
    reward: { type: Schema.Types.ObjectId, ref: 'Reward', default: null },
    active: { type: Boolean, default: true },
    sortOrder: { type: Number, default: 0 },
  },
  { timestamps: true, collection: 'quests' },
);

export const Quest = model('Quest', questSchema);

/** user_quests — user_id, quest_id, progress, status. */
const userQuestSchema = new Schema(
  {
    user: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    quest: { type: Schema.Types.ObjectId, ref: 'Quest', required: true },
    progress: { type: Number, default: 0, min: 0 },
    status: { type: String, enum: USER_QUEST_STATUSES, default: 'in_progress' },
    visitedSpots: { type: [Schema.Types.ObjectId], default: [] }, // for unique_spots goals
    completedAt: { type: Date, default: null },
    claimedAt: { type: Date, default: null },
  },
  { timestamps: true, collection: 'user_quests' },
);

userQuestSchema.index({ user: 1, quest: 1 }, { unique: true });

export const UserQuest = model('UserQuest', userQuestSchema);
