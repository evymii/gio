import { describe, expect, it } from 'vitest';
import { signup, useTestDatabase } from './setup.js';

const here = { lat: 37.3349, lng: -122.009 };

async function befriend(a: Awaited<ReturnType<typeof signup>>, b: Awaited<ReturnType<typeof signup>>) {
  const req = await a.post('/api/v1/friends/requests', { userId: b.id });
  await b.post(`/api/v1/friends/${req.body.data.friendshipId}/accept`);
}

describe('friends + location sharing', () => {
  useTestDatabase();

  it('sends, lists, accepts and removes friend requests', async () => {
    const a = await signup('Alice'), b = await signup('Bob');
    const sent = await a.post('/api/v1/friends/requests', { userId: b.id });
    expect(sent.status).toBe(201);
    expect((await b.get('/api/v1/friends')).body.data.incoming[0].user.name).toBe('Alice');
    expect((await a.get('/api/v1/friends')).body.data.outgoing).toHaveLength(1);
    // Only the addressee can accept.
    expect((await a.post(`/api/v1/friends/${sent.body.data.friendshipId}/accept`)).status).toBe(404);
    expect((await b.post(`/api/v1/friends/${sent.body.data.friendshipId}/accept`)).body.data.status).toBe('accepted');
    expect((await a.get('/api/v1/friends')).body.data.friends[0].user.name).toBe('Bob');
    expect((await b.del(`/api/v1/friends/${sent.body.data.friendshipId}`)).status).toBe(204);
    expect((await a.get('/api/v1/friends')).body.data.friends).toHaveLength(0);
  });

  it('a request back to someone who asked you accepts it', async () => {
    const a = await signup('Cat'), b = await signup('Dan');
    await a.post('/api/v1/friends/requests', { userId: b.id });
    const back = await b.post('/api/v1/friends/requests', { userId: a.id });
    expect(back.body.data.status).toBe('accepted');
  });

  it('shows friends on the map, never strangers, and respects ghost mode', async () => {
    const me = await signup('Me'), friend = await signup('Friend'), stranger = await signup('Stranger');
    await befriend(me, friend);
    for (const u of [friend, stranger]) {
      const up = await u.post('/api/v1/locations', { points: [{ ...here, accuracyMeters: 8 }] });
      expect(up.status).toBe(201);
    }
    let map = await me.get('/api/v1/locations/friends');
    expect(map.body.data.map((f: { user: { name: string } }) => f.user.name)).toEqual(['Friend']);
    expect(map.body.data[0]).toMatchObject({ online: true, location: { lat: here.lat, lng: here.lng } });

    await friend.patch('/api/v1/users/me', { locationSharing: 'off' });
    map = await me.get('/api/v1/locations/friends');
    expect(map.body.data).toHaveLength(0);
    // While off, raw history isn't stored.
    const up = await friend.post('/api/v1/locations', { points: [here] });
    expect(up.body.data.stored).toBe(false);
  });

  it('validates location uploads', async () => {
    const u = await signup('Val');
    expect((await u.post('/api/v1/locations', { points: [] })).status).toBe(400);
    expect((await u.post('/api/v1/locations', { points: [{ lat: 95, lng: 0 }] })).status).toBe(400);
  });
});
