import { Types } from 'mongoose';
import { ALL_TIME, isoWeekKey } from '../../lib/periods.js';
import { toPublicUserDTO } from '../users/user.dto.js';
import { LeaderboardEntry } from './leaderboard.model.js';

export type PeriodName = 'weekly' | 'all_time';
const periodKey = (p: PeriodName) => (p === 'weekly' ? isoWeekKey() : ALL_TIME);

type Populated = { _id: Types.ObjectId; name: string; avatar: string; xp: number };

/** Top N for a region (null = campus-wide) and period, plus your own rank. */
export async function leaderboard(userId: string, period: PeriodName, region: Types.ObjectId | null, limit = 20) {
  const key = periodKey(period);
  const top = await LeaderboardEntry.find({ region, period: key, score: { $gt: 0 } })
    .sort({ score: -1, updatedAt: 1 })
    .limit(limit)
    .populate<{ user: Populated }>('user', 'name avatar xp');

  const mine = await LeaderboardEntry.findOne({ region, period: key, user: new Types.ObjectId(userId) });
  const myScore = mine?.score ?? 0;
  const myRank = myScore > 0 ? (await LeaderboardEntry.countDocuments({ region, period: key, score: { $gt: myScore } })) + 1 : null;

  return {
    period,
    periodKey: key,
    regionId: region ? String(region) : null,
    entries: top.filter((e) => e.user).map((e, i) => ({ rank: i + 1, score: e.score, user: toPublicUserDTO(e.user), isMe: e.user._id.equals(userId) })),
    me: { rank: myRank, score: myScore },
  };
}
