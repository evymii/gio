import { Schema, model } from 'mongoose';

/**
 * leaderboards — user_id, region_id, period, score.
 * region null = campus-wide; period "all_time" or "week:2026-W46".
 */
const leaderboardSchema = new Schema(
  {
    user: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    region: { type: Schema.Types.ObjectId, ref: 'Region', default: null },
    period: { type: String, required: true },
    score: { type: Number, default: 0 },
  },
  { timestamps: true, collection: 'leaderboards' },
);

leaderboardSchema.index({ user: 1, region: 1, period: 1 }, { unique: true });
leaderboardSchema.index({ region: 1, period: 1, score: -1 });

export const LeaderboardEntry = model('LeaderboardEntry', leaderboardSchema);
