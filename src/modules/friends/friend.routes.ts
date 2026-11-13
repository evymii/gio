import { Router } from 'express';
import { Types } from 'mongoose';
import { z } from 'zod';
import { requireAuth } from '../../middleware/auth.js';
import { validate } from '../../middleware/validate.js';
import { ApiError } from '../../utils/ApiError.js';
import { toPublicUserDTO } from '../users/user.dto.js';
import { User } from '../users/user.model.js';
import { Friendship } from './friendship.model.js';

const objectId = z.string().regex(/^[a-f\d]{24}$/i, 'Invalid id');
const requestSchema = z.object({ userId: objectId });
const idParams = z.object({ id: objectId });

type Populated = { _id: Types.ObjectId; name: string; avatar: string; xp: number };

/** /api/v1/friends — requests, accepting, listing, removing. */
export const friendsRouter = Router();
friendsRouter.use(requireAuth);

/** Accepted friends + pending requests (incoming and outgoing). */
friendsRouter.get('/', async (req, res) => {
  const me = new Types.ObjectId(req.userId);
  const rows = await Friendship.find({ $or: [{ user: me }, { friend: me }] })
    .populate<{ user: Populated; friend: Populated }>('user friend', 'name avatar xp')
    .sort({ updatedAt: -1 });
  type Item = { friendshipId: string; user: ReturnType<typeof toPublicUserDTO>; since: string };
  const friends: Item[] = [], incoming: Item[] = [], outgoing: Item[] = [];
  for (const r of rows) {
    const iSent = r.user._id.equals(me);
    const other = iSent ? r.friend : r.user;
    const item = { friendshipId: String(r._id), user: toPublicUserDTO(other), since: (r.acceptedAt ?? r.createdAt).toISOString() };
    if (r.status === 'accepted') friends.push(item);
    else (iSent ? outgoing : incoming).push(item);
  }
  res.json({ data: { friends, incoming, outgoing } });
});

/** Send a request. If they already asked you, this accepts it. */
friendsRouter.post('/requests', validate(requestSchema), async (req, res) => {
  const target: string = res.locals.body.userId;
  if (target === req.userId) throw ApiError.badRequest("You can't add yourself");
  if (!(await User.exists({ _id: target }))) throw ApiError.notFound('User not found');

  const reverse = await Friendship.findOne({ user: target, friend: req.userId });
  if (reverse) {
    if (reverse.status === 'pending') {
      reverse.status = 'accepted';
      reverse.acceptedAt = new Date();
      await reverse.save();
    }
    return res.json({ data: { friendshipId: String(reverse._id), status: reverse.status } });
  }
  const existing = await Friendship.findOne({ user: req.userId, friend: target });
  if (existing) return res.json({ data: { friendshipId: String(existing._id), status: existing.status } });

  const f = await Friendship.create({ user: req.userId, friend: target });
  res.status(201).json({ data: { friendshipId: String(f._id), status: f.status } });
});

/** Accept an incoming request (only the addressee can). */
friendsRouter.post('/:id/accept', validate(idParams, 'params'), async (req, res) => {
  const f = await Friendship.findOne({ _id: res.locals.params.id, friend: req.userId, status: 'pending' });
  if (!f) throw ApiError.notFound('Friend request not found');
  f.status = 'accepted';
  f.acceptedAt = new Date();
  await f.save();
  res.json({ data: { friendshipId: String(f._id), status: f.status } });
});

/** Decline, cancel or unfriend — either side can remove the row. */
friendsRouter.delete('/:id', validate(idParams, 'params'), async (req, res) => {
  const r = await Friendship.deleteOne({ _id: res.locals.params.id, $or: [{ user: req.userId }, { friend: req.userId }] });
  if (r.deletedCount === 0) throw ApiError.notFound('Friendship not found');
  res.status(204).end();
});
