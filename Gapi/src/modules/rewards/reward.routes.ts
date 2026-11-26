import { Router } from 'express';
import { requireAuth } from '../../middleware/auth.js';
import { InventoryItem, Reward } from './reward.model.js';

type RewardLike = { _id: unknown; slug: string; name: string; type: string; value: string; description?: string | null; icon: string };
export const toRewardDTO = (r: RewardLike) => ({
  id: String(r._id), slug: r.slug, name: r.name, type: r.type, value: r.value, description: r.description ?? '', icon: r.icon,
});

/** /api/v1/rewards (catalog) and /api/v1/inventory (what you own). */
export const rewardsRouter = Router();
rewardsRouter.use(requireAuth);
rewardsRouter.get('/', async (_req, res) => {
  res.json({ data: (await Reward.find().sort({ type: 1, name: 1 })).map(toRewardDTO) });
});

export const inventoryRouter = Router();
inventoryRouter.use(requireAuth);
inventoryRouter.get('/', async (req, res) => {
  const items = await InventoryItem.find({ user: req.userId, qty: { $gt: 0 } })
    .sort({ claimedAt: -1 })
    .populate<{ reward: RewardLike }>('reward');
  res.json({
    data: items.filter((i) => i.reward).map((i) => ({ reward: toRewardDTO(i.reward), qty: i.qty, claimedAt: i.claimedAt.toISOString() })),
  });
});
