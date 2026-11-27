import { SignJWT, createLocalJWKSet, exportJWK, generateKeyPair } from 'jose';
import request from 'supertest';
import { beforeAll, describe, expect, it } from 'vitest';
import { setFirebaseKeysForTesting } from '../src/lib/firebase.js';
import { app, signup, useTestDatabase } from './setup.js';

const PROJECT = 'gio-game-a335a';
let privateKey: CryptoKey;

/** A token shaped like the ones Firebase Auth issues after phone sign-in. */
function firebaseToken(uid: string, phone: string, opts: { audience?: string; key?: CryptoKey } = {}) {
  return new SignJWT({ phone_number: phone, firebase: { sign_in_provider: 'phone' } })
    .setProtectedHeader({ alg: 'RS256', kid: 'test-key' })
    .setIssuer(`https://securetoken.google.com/${PROJECT}`)
    .setAudience(opts.audience ?? PROJECT)
    .setSubject(uid)
    .setIssuedAt()
    .setExpirationTime('1h')
    .sign(opts.key ?? privateKey);
}

const exchange = (idToken: string) => request(app).post('/api/v1/auth/firebase').send({ idToken });

describe('phone sign-in via Firebase', () => {
  useTestDatabase();

  beforeAll(async () => {
    const pair = await generateKeyPair('RS256');
    privateKey = pair.privateKey;
    const jwk = { ...(await exportJWK(pair.publicKey)), kid: 'test-key', alg: 'RS256' };
    setFirebaseKeysForTesting(createLocalJWKSet({ keys: [jwk] }));
  });

  it('creates an account the first time, then signs the same person back in', async () => {
    const first = await exchange(await firebaseToken('uid-1', '+97699999999'));
    expect(first.status).toBe(200);
    expect(first.body.data).toMatchObject({ isNew: true, user: { name: 'Player 9999', phone: '+97699999999', email: null } });

    const me = await request(app).get('/api/v1/users/me').set('Authorization', `Bearer ${first.body.data.accessToken}`);
    expect(me.body.data.phone).toBe('+97699999999');

    const again = await exchange(await firebaseToken('uid-1', '+97699999999'));
    expect(again.body.data).toMatchObject({ isNew: false, user: { id: first.body.data.user.id } });
  });

  it('rejects tokens for another project or signed by someone else', async () => {
    expect((await exchange(await firebaseToken('uid-2', '+97688888888', { audience: 'other-project' }))).status).toBe(401);
    const stranger = (await generateKeyPair('RS256')).privateKey;
    const forged = await exchange(await firebaseToken('uid-2', '+97688888888', { key: stranger }));
    expect(forged.status).toBe(401);
    expect(forged.body.error.code).toBe('FIREBASE_TOKEN_INVALID');
  });

  it('lets phone and email users coexist and find each other by phone', async () => {
    const emailUser = await signup('Mail');
    await exchange(await firebaseToken('uid-3', '+97677777777'));
    await exchange(await firebaseToken('uid-4', '+97666666666'));
    const found = await emailUser.get('/api/v1/users/search?q=%2B976%2077777777');
    expect(found.body.data.map((u: { name: string }) => u.name)).toEqual(['Player 7777']);
  });
});
