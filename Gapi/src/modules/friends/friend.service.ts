import { Types } from 'mongoose';
import { Friendship } from './friendship.model.js';

/** Ids of everyone you're friends with (accepted, either direction). */
export async function acceptedFriendIds(userId: string): Promise<Types.ObjectId[]> {
  const me = new Types.ObjectId(userId);
  const rows = await Friendship.find({ status: 'accepted', $or: [{ user: me }, { friend: me }] }).lean();
  return rows.map((r) => (r.user.equals(me) ? r.friend : r.user));
}
