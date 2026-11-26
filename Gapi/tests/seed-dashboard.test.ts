import request from 'supertest';
import { describe, expect, it } from 'vitest';
import { runSeed } from '../src/db/seed/seed.js';
import { User } from '../src/modules/users/user.model.js';
import { app, CENTER, signup, useTestDatabase } from './setup.js';

async function loginDemo() {
  const res = await request(app).post('/api/v1/auth/login').send({ email: 'demo@gios.app', password: 'campus123' });
  expect(res.status).toBe(200);
  const token = res.body.data.accessToken;
  return (path: string) => request(app).get(path).set('Authorization', `Bearer ${token}`);
}

describe('seed + dashboard', () => {
  useTestDatabase();

  it('creates every collection and is idempotent', async () => {
    const first = await runSeed({ center: CENTER, password: 'campus123' });
    expect(first.collections).toMatchObject({
      users: 7, regions: 2, spots: 12, rewards: 6, quests: 6, events: 2, friends: 8, checkins: 30, devices: 1,
    });
    const second = await runSeed({ center: CENTER, password: 'campus123' });
    expect(second.collections).toEqual(first.collections);
  });

  it('never touches real users', async () => {
    const real = await signup('RealPerson');
    await runSeed({ center: CENTER, password: 'campus123' });
    await runSeed({ center: CENTER, password: 'campus123', reset: true });
    expect(await User.exists({ _id: real.id })).toBeTruthy();
  });

  it('gives the demo user a full dashboard', async () => {
    await runSeed({ center: CENTER, password: 'campus123' });
    const get = await loginDemo();
    const d = (await get(`/api/v1/dashboard?lat=${CENTER.lat}&lng=${CENTER.lng}`)).body.data;

    expect(d.user.name).toBe('Demo Student');
    expect(d.user.xp).toBeGreaterThan(0);
    expect(d.region.slug).toBe('north-campus');
    expect(d.stats).toMatchObject({ checkinsTotal: 4, uniqueSpots: 4, friends: 4 });
    expect(d.nearbySpots[0].slug).toBe('main-gate');
    // Mio (2 min) and Ana (6 min) are online; Kai is stale (45 min); Sora is in ghost mode.
    expect(d.friendsOnline.users.map((f: { user: { name: string } }) => f.user.name).sort()).toEqual(['Ana', 'Mio']);
    expect(d.friendsOnline.total).toBe(4);
    // Coffee Run is complete but unclaimed → shown first.
    expect(d.quests[0]).toMatchObject({ slug: 'coffee-run', status: 'completed' });
    expect(d.events.map((e: { slug: string }) => e.slug)).toContain('welcome-week');
    expect(d.leaderboard.top.length).toBeGreaterThan(0);

    const friendsMap = (await get('/api/v1/locations/friends')).body.data;
    expect(friendsMap.map((f: { user: { name: string } }) => f.user.name).sort()).toEqual(['Ana', 'Kai', 'Mio']);
    const pending = (await get('/api/v1/friends')).body.data;
    expect(pending.incoming[0].user.name).toBe('Leo');
    expect(pending.outgoing[0].user.name).toBe('Rin');
  });
});
