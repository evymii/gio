import { Types } from 'mongoose';
import { env } from '../../config/env.js';
import { geohash, offsetMeters, squarePolygon, toPoint, type LatLng } from '../../lib/geo.js';
import { levelForXp } from '../../lib/levels.js';
import { ALL_TIME, isoWeekKey } from '../../lib/periods.js';
import { Session } from '../../modules/auth/session.model.js';
import { hashPassword } from '../../modules/auth/auth.service.js';
import { Checkin } from '../../modules/checkins/checkin.model.js';
import { Device } from '../../modules/devices/device.model.js';
import { GameEvent } from '../../modules/events/event.model.js';
import { Friendship } from '../../modules/friends/friendship.model.js';
import { LeaderboardEntry } from '../../modules/leaderboards/leaderboard.model.js';
import { UserLocation } from '../../modules/locations/userLocation.model.js';
import { Quest, UserQuest } from '../../modules/quests/quest.model.js';
import { Region } from '../../modules/regions/region.model.js';
import { InventoryItem, Reward } from '../../modules/rewards/reward.model.js';
import { Spot } from '../../modules/spots/spot.model.js';
import { User } from '../../modules/users/user.model.js';
import * as data from './data.js';

// Typed loosely: a union of 14 model types is too complex for TypeScript to call methods on.
// eslint-disable-next-line @typescript-eslint/no-explicit-any
type AnyModel = import('mongoose').Model<any>;
export const ALL_MODELS: AnyModel[] = [
  User, Session, Device, UserLocation, Friendship, Region, Spot, Checkin,
  Quest, UserQuest, Reward, InventoryItem, LeaderboardEntry, GameEvent,
];

export interface SeedOptions {
  reset?: boolean;
  center?: LatLng;
  password?: string;
  now?: Date;
}

const emailFor = (key: string) => `${key}@${data.SEED_EMAIL_DOMAIN}`;

/**
 * Creates every collection + index, upserts the catalog (regions, spots,
 * rewards, quests, events) and rebuilds the demo users' activity.
 * Idempotent. Real (non-demo) users and their data are never touched.
 */
export async function runSeed(opts: SeedOptions = {}) {
  const center = opts.center ?? { lat: env.SEED_LAT, lng: env.SEED_LNG };
  const password = opts.password ?? env.SEED_PASSWORD;
  const now = opts.now ?? new Date();
  const at = (north: number, east: number) => offsetMeters(center, north, east);

  for (const m of ALL_MODELS) {
    await m.createCollection().catch(() => undefined);
    await m.syncIndexes();
  }

  if (opts.reset) {
    await Promise.all(([Region, Spot, Reward, Quest, GameEvent] as AnyModel[]).map((m) => m.deleteMany({})));
  }

  // ---- catalog ------------------------------------------------------------
  const regionIds = new Map<string, Types.ObjectId>();
  for (const r of data.regions) {
    const doc = await Region.findOneAndUpdate(
      { slug: r.slug },
      { $set: { name: r.name, area: squarePolygon(at(r.center.north, r.center.east), r.halfSize) } },
      { upsert: true, new: true },
    );
    regionIds.set(r.slug, doc._id);
  }
  const regionForOffset = (north: number) => regionIds.get(north >= data.REGION_BORDER_NORTH ? 'north-campus' : 'south-campus')!;

  const spotDocs = new Map<string, { _id: Types.ObjectId; type: string; rewardXp: number; region: Types.ObjectId; pos: LatLng }>();
  for (const s of data.spots) {
    const pos = at(s.north, s.east);
    const region = regionForOffset(s.north);
    const doc = await Spot.findOneAndUpdate(
      { slug: s.slug },
      {
        $set: {
          name: s.name, type: s.type, description: s.description, point: toPoint(pos), geohash: geohash(pos),
          radiusMeters: s.radiusMeters, rewardXp: s.rewardXp, active: true, region,
        },
      },
      { upsert: true, new: true },
    );
    spotDocs.set(s.slug, { _id: doc._id, type: s.type, rewardXp: s.rewardXp, region, pos });
  }

  const rewardIds = new Map<string, Types.ObjectId>();
  for (const r of data.rewards) {
    const { slug, ...rest } = r;
    const doc = await Reward.findOneAndUpdate({ slug }, { $set: rest }, { upsert: true, new: true });
    rewardIds.set(slug, doc._id);
  }

  const questDocs = data.quests.map((q, i) => ({ ...q, sortOrder: i }));
  const questIds = new Map<string, Types.ObjectId>();
  for (const q of questDocs) {
    const doc = await Quest.findOneAndUpdate(
      { slug: q.slug },
      {
        $set: {
          title: q.title, description: q.description,
          goal: { type: q.goal.type, target: q.goal.target, spotType: 'spotType' in q.goal ? q.goal.spotType : null },
          rewardXp: q.rewardXp, reward: rewardIds.get(q.reward) ?? null, active: true, sortOrder: q.sortOrder,
        },
      },
      { upsert: true, new: true },
    );
    questIds.set(q.slug, doc._id);
  }

  for (const e of data.events) {
    const startsAt = new Date(now.getTime() + e.startsInDays * 86_400_000);
    await GameEvent.findOneAndUpdate(
      { slug: e.slug },
      {
        $set: {
          title: e.title, description: e.description, region: e.region ? regionIds.get(e.region) : null,
          startsAt, endsAt: new Date(startsAt.getTime() + e.durationDays * 86_400_000), xpMultiplier: e.xpMultiplier,
        },
      },
      { upsert: true, new: true },
    );
  }

  // ---- demo users: wipe their activity, then rebuild it --------------------
  const passwordHash = await hashPassword(password);
  const userIds = new Map<data.UserKey, Types.ObjectId>();
  for (const u of data.users) {
    const doc = await User.findOneAndUpdate(
      { email: emailFor(u.key) },
      { $set: { name: u.name, avatar: u.avatar, locationSharing: u.sharing, passwordHash, xp: 0, level: 1 }, $unset: { lastLocation: 1 } },
      { upsert: true, new: true },
    );
    userIds.set(u.key, doc._id);
  }
  const ids = [...userIds.values()];
  await Promise.all([
    Checkin.deleteMany({ user: { $in: ids } }),
    UserLocation.deleteMany({ user: { $in: ids } }),
    UserQuest.deleteMany({ user: { $in: ids } }),
    InventoryItem.deleteMany({ user: { $in: ids } }),
    LeaderboardEntry.deleteMany({ user: { $in: ids } }),
    Device.deleteMany({ user: { $in: ids } }),
    Friendship.deleteMany({ user: { $in: ids }, friend: { $in: ids } }),
  ]);

  await Friendship.insertMany(
    data.friendships.map(([a, b, status]) => ({
      user: userIds.get(a), friend: userIds.get(b), status, acceptedAt: status === 'accepted' ? new Date(now.getTime() - 7 * 86_400_000) : null,
    })),
  );

  // Locations: lastLocation + a short trail of raw points for each sharing user.
  for (const u of data.users) {
    if (!u.at) continue;
    const spot = spotDocs.get(u.at.spot)!;
    const trail = [30, 15, 0].map((extra, i) => ({
      pos: offsetMeters(spot.pos, -12 * (2 - i), 8 * (2 - i)),
      recordedAt: new Date(now.getTime() - (u.at!.minutesAgo + extra) * 60_000),
    }));
    if (u.sharing !== 'off') {
      await UserLocation.insertMany(
        trail.map((t) => ({ user: userIds.get(u.key), point: toPoint(t.pos), accuracyMeters: 12, geohash: geohash(t.pos), recordedAt: t.recordedAt })),
      );
    }
    const last = trail[trail.length - 1];
    await User.updateOne(
      { _id: userIds.get(u.key) },
      { $set: { lastLocation: { point: toPoint(last.pos), accuracyMeters: 12, recordedAt: last.recordedAt } } },
    );
  }

  await Device.create({ user: userIds.get('demo'), deviceId: 'seed-demo-iphone', platform: 'ios', locationPermission: 'when_in_use', appVersion: '0.1.0' });

  // Check-ins → XP, leaderboards, quest progress (replayed in time order, same rules as the API).
  const xp = new Map<string, number>();
  const board = new Map<string, number>(); // `${user}|${region|null}|${period}` → score
  const addScore = (user: Types.ObjectId, region: Types.ObjectId | null, when: Date, amount: number) => {
    for (const r of region ? [null, region] : [null]) {
      for (const p of [ALL_TIME, isoWeekKey(when)]) {
        const k = `${user}|${r ?? 'null'}|${p}`;
        board.set(k, (board.get(k) ?? 0) + amount);
      }
    }
    xp.set(String(user), (xp.get(String(user)) ?? 0) + amount);
  };

  type Progress = { progress: number; visited: Set<string>; completedAt: Date | null };
  const progress = new Map<string, Progress>(); // `${user}|${quest}`
  const checkinRows = data.checkins
    .map(([key, slug, daysAgo, hour]) => {
      const d = new Date(now.getTime() - daysAgo * 86_400_000);
      d.setUTCHours(hour, 0, 0, 0);
      if (d > now) d.setTime(now.getTime() - 30 * 60_000);
      return { key, slug, when: d };
    })
    .sort((a, b) => a.when.getTime() - b.when.getTime());

  const checkinDocs = [];
  for (const c of checkinRows) {
    const user = userIds.get(c.key)!;
    const spot = spotDocs.get(c.slug)!;
    const pos = offsetMeters(spot.pos, 5, -5);
    checkinDocs.push({
      user, spot: spot._id, point: toPoint(pos), accuracyMeters: 10, distanceMeters: 7, verified: true,
      xpAwarded: spot.rewardXp, createdAt: c.when, updatedAt: c.when,
    });
    addScore(user, spot.region, c.when, spot.rewardXp);

    for (const q of questDocs) {
      const matches = q.goal.type !== 'spot_type' || ('spotType' in q.goal && q.goal.spotType === spot.type);
      if (!matches) continue;
      const k = `${user}|${q.slug}`;
      const p = progress.get(k) ?? { progress: 0, visited: new Set<string>(), completedAt: null };
      if (p.completedAt) continue;
      if (q.goal.type === 'unique_spots') {
        p.visited.add(String(spot._id));
        p.progress = p.visited.size;
      } else p.progress += 1;
      if (p.progress >= q.goal.target) p.completedAt = c.when;
      progress.set(k, p);
    }
  }
  await Checkin.insertMany(checkinDocs, { timestamps: false } as never);

  const userQuestDocs = [];
  const inventory = new Map<string, { user: Types.ObjectId; reward: Types.ObjectId; qty: number; claimedAt: Date }>();
  for (const [k, p] of progress) {
    const [userStr, slug] = k.split('|');
    const quest = questDocs.find((q) => q.slug === slug)!;
    const user = new Types.ObjectId(userStr);
    const isDemo = user.equals(userIds.get('demo')!);
    const claim = p.completedAt && !(isDemo && data.unclaimedForDemo.includes(slug));
    userQuestDocs.push({
      user, quest: questIds.get(slug), progress: Math.min(p.progress, quest.goal.target),
      status: p.completedAt ? (claim ? 'claimed' : 'completed') : 'in_progress',
      visitedSpots: [...p.visited].map((s) => new Types.ObjectId(s)),
      completedAt: p.completedAt, claimedAt: claim ? p.completedAt : null,
    });
    if (claim && p.completedAt) {
      addScore(user, null, p.completedAt, quest.rewardXp);
      const reward = rewardIds.get(quest.reward)!;
      const ik = `${user}|${reward}`;
      const item = inventory.get(ik) ?? { user, reward, qty: 0, claimedAt: p.completedAt };
      item.qty += 1;
      inventory.set(ik, item);
    }
  }
  if (userQuestDocs.length) await UserQuest.insertMany(userQuestDocs);
  if (inventory.size) await InventoryItem.insertMany([...inventory.values()]);

  await LeaderboardEntry.insertMany(
    [...board].map(([k, score]) => {
      const [user, region, period] = k.split('|');
      return { user: new Types.ObjectId(user), region: region === 'null' ? null : new Types.ObjectId(region), period, score };
    }),
  );
  await User.bulkWrite(
    [...xp].map(([id, total]) => ({ updateOne: { filter: { _id: new Types.ObjectId(id) }, update: { $set: { xp: total, level: levelForXp(total) } } } })),
  );

  const counts = await Promise.all(ALL_MODELS.map((m) => m.countDocuments()));
  return {
    center,
    demoLogin: { email: emailFor('demo'), password },
    collections: Object.fromEntries(ALL_MODELS.map((m, i) => [m.collection.collectionName, counts[i]])),
  };
}
