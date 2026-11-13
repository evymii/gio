import { Types } from 'mongoose';
import { ApiError } from '../../utils/ApiError.js';
import { InventoryItem, Reward } from '../rewards/reward.model.js';
import { awardXp } from '../users/xp.service.js';
import { Quest, UserQuest } from './quest.model.js';

type SpotForProgress = { _id: Types.ObjectId; type: string };

export function toQuestDTO(
  q: { _id: unknown; slug: string; title: string; description?: string | null; goal: { type: string; target: number; spotType?: string | null }; rewardXp: number; reward?: unknown },
  uq?: { progress: number; status: string; completedAt?: Date | null; claimedAt?: Date | null } | null,
  reward?: { _id: unknown; name: string; type: string; icon: string } | null,
) {
  return {
    id: String(q._id),
    slug: q.slug,
    title: q.title,
    description: q.description ?? '',
    goal: { type: q.goal.type, target: q.goal.target, spotType: q.goal.spotType ?? null },
    rewardXp: q.rewardXp,
    reward: reward ? { id: String(reward._id), name: reward.name, type: reward.type, icon: reward.icon } : null,
    progress: Math.min(uq?.progress ?? 0, q.goal.target),
    status: uq?.status ?? 'in_progress',
    completedAt: uq?.completedAt?.toISOString() ?? null,
    claimedAt: uq?.claimedAt?.toISOString() ?? null,
  };
}

/** All active quests with your progress. */
export async function questsFor(userId: string) {
  const [quests, mine] = await Promise.all([
    Quest.find({ active: true }).sort({ sortOrder: 1 }).populate<{ reward: { _id: unknown; name: string; type: string; icon: string } | null }>('reward'),
    UserQuest.find({ user: userId }),
  ]);
  const byQuest = new Map(mine.map((u) => [String(u.quest), u]));
  return quests.map((q) => toQuestDTO(q, byQuest.get(String(q._id)), q.reward));
}

/** Advances every active quest a verified check-in counts toward. Returns the quests that changed. */
export async function recordCheckinProgress(userId: Types.ObjectId, spot: SpotForProgress) {
  const quests = await Quest.find({ active: true });
  const changed: { questId: string; title: string; progress: number; target: number; completed: boolean }[] = [];

  for (const q of quests) {
    const matches = q.goal.type === 'checkins' || q.goal.type === 'unique_spots' || (q.goal.type === 'spot_type' && q.goal.spotType === spot.type);
    if (!matches) continue;

    const uq = await UserQuest.findOneAndUpdate(
      { user: userId, quest: q._id },
      { $setOnInsert: { progress: 0, status: 'in_progress' } },
      { upsert: true, new: true },
    );
    if (uq.status !== 'in_progress') continue;

    if (q.goal.type === 'unique_spots') {
      if (uq.visitedSpots.some((s) => s.equals(spot._id))) continue;
      uq.visitedSpots.push(spot._id);
      uq.progress = uq.visitedSpots.length;
    } else {
      uq.progress += 1;
    }
    const completed = uq.progress >= q.goal.target;
    if (completed) {
      uq.status = 'completed';
      uq.completedAt = new Date();
    }
    await uq.save();
    changed.push({ questId: String(q._id), title: q.title, progress: Math.min(uq.progress, q.goal.target), target: q.goal.target, completed });
  }
  return changed;
}

/** Claim a completed quest: grants its XP and puts its reward in your inventory. */
export async function claimQuest(userId: string, questId: string) {
  const quest = await Quest.findById(questId);
  if (!quest) throw ApiError.notFound('Quest not found');
  const uq = await UserQuest.findOneAndUpdate(
    { user: userId, quest: quest._id, status: 'completed' },
    { $set: { status: 'claimed', claimedAt: new Date() } },
    { new: true },
  );
  if (!uq) {
    const existing = await UserQuest.findOne({ user: userId, quest: quest._id });
    if (existing?.status === 'claimed') throw ApiError.conflict('Already claimed', 'ALREADY_CLAIMED');
    throw ApiError.conflict('Quest not completed yet', 'NOT_COMPLETED');
  }
  const xp = await awardXp(userId, quest.rewardXp);
  const r = quest.reward ? await Reward.findById(quest.reward) : null;
  if (r) {
    await InventoryItem.findOneAndUpdate(
      { user: userId, reward: r._id },
      { $inc: { qty: 1 }, $set: { claimedAt: new Date() } },
      { upsert: true, new: true },
    );
  }
  const dto = toQuestDTO(quest, uq, r);
  return { quest: dto, xpAwarded: quest.rewardXp, user: xp, reward: dto.reward };
}
