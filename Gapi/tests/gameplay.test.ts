import { describe, expect, it } from 'vitest';
import { offsetMeters } from '../src/lib/geo.js';
import { runSeed } from '../src/db/seed/seed.js';
import { CENTER, signup, useTestDatabase } from './setup.js';

describe('spots, check-ins, quests, leaderboards', () => {
  useTestDatabase();

  async function setup() {
    await runSeed({ center: CENTER, password: 'campus123' });
    const u = await signup('Player');
    const spots = await u.get(`/api/v1/spots/nearby?lat=${CENTER.lat}&lng=${CENTER.lng}&radius=300`);
    const gate = spots.body.data.find((s: { slug: string }) => s.slug === 'main-gate');
    return { u, gate, spots: spots.body.data };
  }

  it('lists nearby spots nearest-first with range info', async () => {
    const { spots, gate } = await setup();
    expect(spots[0].slug).toBe('main-gate');
    expect(gate).toMatchObject({ inRange: true, cooldownUntil: null, type: 'landmark' });
    const dists = spots.map((s: { distanceMeters: number }) => s.distanceMeters);
    expect([...dists].sort((a, b) => a - b)).toEqual(dists);
  });

  it('refuses to verify a check-in from too far away', async () => {
    const { u, gate } = await setup();
    const far = offsetMeters(CENTER, 400, 0);
    const res = await u.post('/api/v1/checkins', { spotId: gate.id, ...far, accuracyMeters: 5 });
    expect(res.status).toBe(200);
    expect(res.body.data.checkin).toMatchObject({ verified: false, xpAwarded: 0 });
    expect(res.body.data.message).toMatch(/Get closer/);
  });

  it('verifies a close check-in: XP, quest progress, leaderboard, cooldown', async () => {
    const { u, gate } = await setup();
    const res = await u.post('/api/v1/checkins', { spotId: gate.id, ...CENTER, accuracyMeters: 10 });
    expect(res.status).toBe(201);
    expect(res.body.data.checkin).toMatchObject({ verified: true, xpAwarded: 20 });
    expect(res.body.data.user).toMatchObject({ xp: 20, level: 1 });
    const firstSteps = res.body.data.quests.find((q: { title: string }) => q.title === 'First Steps');
    expect(firstSteps).toMatchObject({ completed: true, progress: 1, target: 1 });

    const again = await u.post('/api/v1/checkins', { spotId: gate.id, ...CENTER });
    expect(again.status).toBe(409);
    expect(again.body.error.code).toBe('COOLDOWN');

    const board = await u.get('/api/v1/leaderboards?period=weekly');
    expect(board.body.data.me.score).toBe(20);
    const allTime = await u.get('/api/v1/leaderboards?period=all_time');
    expect(allTime.body.data.entries.some((e: { isMe: boolean; score: number }) => e.isMe && e.score === 20)).toBe(true);
  });

  it('claims a completed quest once for its XP', async () => {
    const { u, gate } = await setup();
    await u.post('/api/v1/checkins', { spotId: gate.id, ...CENTER });
    const quests = (await u.get('/api/v1/quests')).body.data;
    const first = quests.find((q: { slug: string }) => q.slug === 'first-steps');
    expect(first.status).toBe('completed');
    const notDone = quests.find((q: { slug: string }) => q.slug === 'bookworm');
    expect((await u.post(`/api/v1/quests/${notDone.id}/claim`)).body.error.code).toBe('NOT_COMPLETED');

    const claim = await u.post(`/api/v1/quests/${first.id}/claim`);
    expect(claim.status).toBe(200);
    expect(claim.body.data).toMatchObject({ xpAwarded: 50, user: { xp: 70 } });
    expect((await u.post(`/api/v1/quests/${first.id}/claim`)).body.error.code).toBe('ALREADY_CLAIMED');
    // Only the built-in avatars can be picked.
    expect((await u.patch('/api/v1/users/me', { avatar: 'avatar-cafe' })).status).toBe(400);
    expect((await u.patch('/api/v1/users/me', { avatar: 'avatar-5' })).body.data.avatar).toBe('avatar-5');
  });
});
