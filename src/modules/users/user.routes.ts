import { Router } from 'express';
import { z } from 'zod';
import { requireAuth } from '../../middleware/auth.js';
import { validate } from '../../middleware/validate.js';
import { ApiError } from '../../utils/ApiError.js';
import { InventoryItem, Reward } from '../rewards/reward.model.js';
import { toMeDTO, toPublicUserDTO } from './user.dto.js';
import { SHARING_MODES, User } from './user.model.js';

const updateMeSchema = z
  .object({
    name: z.string().trim().min(2).max(30).optional(),
    avatar: z.string().trim().min(1).max(40).optional(),
    locationSharing: z.enum(SHARING_MODES).optional(),
  })
  .refine((v) => Object.keys(v).length > 0, 'Provide at least one field');

const searchSchema = z.object({ q: z.string().trim().min(2).max(60) });

/** Avatars everyone can use; reward avatars (e.g. "avatar-cafe") must be in your inventory. */
export const FREE_AVATARS = Array.from({ length: 8 }, (_, i) => `avatar-${i + 1}`);

async function canUseAvatar(userId: string, avatar: string) {
  if (FREE_AVATARS.includes(avatar)) return true;
  const reward = await Reward.findOne({ type: 'avatar', value: avatar });
  if (!reward) return false;
  return !!(await InventoryItem.exists({ user: userId, reward: reward._id, qty: { $gt: 0 } }));
}

/** /api/v1/users — your profile + finding people to add as friends. */
export const usersRouter = Router();
usersRouter.use(requireAuth);

usersRouter.get('/me', async (req, res) => {
  const me = await User.findById(req.userId);
  if (!me) throw ApiError.unauthorized('Account no longer exists');
  res.json({ data: toMeDTO(me) });
});

usersRouter.patch('/me', validate(updateMeSchema), async (req, res) => {
  const { avatar } = res.locals.body as z.infer<typeof updateMeSchema>;
  if (avatar && !(await canUseAvatar(req.userId, avatar))) {
    throw ApiError.forbidden("You haven't unlocked that avatar yet");
  }
  const me = await User.findByIdAndUpdate(req.userId, res.locals.body, { new: true, runValidators: true });
  if (!me) throw ApiError.unauthorized('Account no longer exists');
  res.json({ data: toMeDTO(me) });
});

/** Search by name prefix or exact email (to send a friend request). */
usersRouter.get('/search', validate(searchSchema, 'query'), async (req, res) => {
  const q: string = res.locals.query.q;
  const escaped = q.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const users = await User.find({
    _id: { $ne: req.userId },
    $or: [{ name: { $regex: `^${escaped}`, $options: 'i' } }, { email: q.toLowerCase() }],
  }).limit(10);
  res.json({ data: users.map(toPublicUserDTO) });
});
