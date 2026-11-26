import request from 'supertest';
import { describe, expect, it } from 'vitest';
import { app, signup, useTestDatabase } from './setup.js';

describe('auth', () => {
  useTestDatabase();

  it('signs up and returns tokens + profile (no password hash)', async () => {
    const res = await request(app).post('/api/v1/auth/signup').send({ name: 'Mio', email: 'Mio@Test.dev', password: 'password123' });
    expect(res.status).toBe(201);
    expect(res.body.data.user).toMatchObject({ name: 'Mio', email: 'mio@test.dev', level: 1, xp: 0, locationSharing: 'friends' });
    expect(res.body.data.user).not.toHaveProperty('passwordHash');
    expect(res.body.data.accessToken).toBeTruthy();
    expect(res.body.data.refreshToken).toBeTruthy();
  });

  it('rejects a duplicate email and weak input', async () => {
    const u = await signup('Ana');
    const dup = await request(app).post('/api/v1/auth/signup').send({ name: 'Ana2', email: u.email, password: 'password123' });
    expect(dup.status).toBe(409);
    expect(dup.body.error.code).toBe('EMAIL_TAKEN');
    const weak = await request(app).post('/api/v1/auth/signup').send({ name: 'A', email: 'nope', password: '123' });
    expect(weak.status).toBe(400);
    expect(weak.body.error.details.map((d: { path: string }) => d.path).sort()).toEqual(['email', 'name', 'password']);
  });

  it('logs in with the right password only', async () => {
    const u = await signup('Kai');
    const bad = await request(app).post('/api/v1/auth/login').send({ email: u.email, password: 'wrong-password' });
    expect(bad.status).toBe(401);
    expect(bad.body.error.code).toBe('INVALID_CREDENTIALS');
    const unknown = await request(app).post('/api/v1/auth/login').send({ email: 'ghost@test.dev', password: 'password123' });
    expect(unknown.body.error.code).toBe('INVALID_CREDENTIALS'); // same error: no account enumeration
    const ok = await request(app).post('/api/v1/auth/login').send({ email: u.email.toUpperCase(), password: 'password123' });
    expect(ok.status).toBe(200);
    expect(ok.body.data.user.id).toBe(u.id);
  });

  it('protects routes and reads the profile', async () => {
    expect((await request(app).get('/api/v1/users/me')).status).toBe(401);
    expect((await request(app).get('/api/v1/users/me').set('Authorization', 'Bearer junk')).body.error.code).toBe('TOKEN_INVALID');
    const u = await signup('Rin');
    const me = await u.get('/api/v1/users/me');
    expect(me.body.data).toMatchObject({ id: u.id, name: 'Rin', level: 1, nextLevelXp: 100 });
  });

  it('rotates refresh tokens and logs out', async () => {
    const u = await signup('Leo');
    const r1 = await request(app).post('/api/v1/auth/refresh').send({ refreshToken: u.refreshToken });
    expect(r1.status).toBe(200);
    // The old refresh token is now spent.
    expect((await request(app).post('/api/v1/auth/refresh').send({ refreshToken: u.refreshToken })).status).toBe(401);
    const next = r1.body.data.refreshToken;
    expect((await request(app).post('/api/v1/auth/logout').send({ refreshToken: next })).status).toBe(204);
    expect((await request(app).post('/api/v1/auth/refresh').send({ refreshToken: next })).status).toBe(401);
  });

  it('updates the profile', async () => {
    const u = await signup('Sora');
    const p = await u.patch('/api/v1/users/me', { name: 'Sora S', locationSharing: 'off' });
    expect(p.body.data).toMatchObject({ name: 'Sora S', locationSharing: 'off' });
  });
});
