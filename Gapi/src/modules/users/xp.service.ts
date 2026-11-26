import type { Types } from 'mongoose';
import { levelForXp } from '../../lib/levels.js';
import { ALL_TIME, isoWeekKey } from '../../lib/periods.js';
import { ApiError } from '../../utils/ApiError.js';
import { LeaderboardEntry } from '../leaderboards/leaderboard.model.js';
import { User } from './user.model.js';

/**
 * The single place XP is granted: updates the user's xp/level and every
 * leaderboard row it counts toward (campus-wide + region, all-time + this week).
 */
export async function awardXp(userId: string | Types.ObjectId, amount: number, region: Types.ObjectId | null = null, at = new Date()) {
  const user = await User.findById(userId);
  if (!user) throw ApiError.unauthorized();
  const before = user.level;
  user.xp += amount;
  user.level = levelForXp(user.xp);
  await user.save();

  if (amount > 0) {
    const regions = region ? [null, region] : [null];
    const periods = [ALL_TIME, isoWeekKey(at)];
    await LeaderboardEntry.bulkWrite(
      regions.flatMap((r) =>
        periods.map((period) => ({
          updateOne: { filter: { user: user._id, region: r, period }, update: { $inc: { score: amount } }, upsert: true },
        })),
      ),
    );
  }
  return { xp: user.xp, level: user.level, leveledUp: user.level > before };
}
