import { MongoMemoryServer } from 'mongodb-memory-server';
import mongoose from 'mongoose';
import request from 'supertest';
import { afterAll, afterEach, beforeAll } from 'vitest';
import { createApp } from '../src/app.js';
import { connectMongo, disconnectMongo } from '../src/db/mongo.js';
import { ALL_MODELS } from '../src/db/seed/seed.js';

let mongo: MongoMemoryServer;

export const app = createApp({ logRequests: false, rateLimit: false });

/** Fresh in-memory MongoDB per test file; collections wiped after each test. */
export function useTestDatabase() {
  beforeAll(async () => {
    mongo = await MongoMemoryServer.create();
    await connectMongo(mongo.getUri('gapi-test'));
    for (const m of ALL_MODELS) await m.syncIndexes(); // geo indexes must exist for $geoNear
  });
  afterEach(async () => {
    const cols = await mongoose.connection.db!.collections();
    await Promise.all(cols.map((c) => c.deleteMany({})));
  });
  afterAll(async () => {
    await disconnectMongo();
    await mongo.stop();
  });
}

let n = 0;
/** Signs up a fresh user; returns its token + id + an authed request helper. */
export async function signup(name = `User${++n}`) {
  const res = await request(app)
    .post('/api/v1/auth/signup')
    .send({ name, email: `${name.toLowerCase()}${n}@test.dev`, password: 'password123' });
  if (res.status !== 201) throw new Error(`signup failed: ${JSON.stringify(res.body)}`);
  const token: string = res.body.data.accessToken;
  const auth = (r: request.Test) => r.set('Authorization', `Bearer ${token}`);
  return {
    id: res.body.data.user.id as string,
    email: res.body.data.user.email as string,
    token,
    refreshToken: res.body.data.refreshToken as string,
    get: (path: string) => auth(request(app).get(path)),
    post: (path: string, body?: object) => auth(request(app).post(path)).send(body ?? {}),
    patch: (path: string, body: object) => auth(request(app).patch(path)).send(body),
    put: (path: string, body: object) => auth(request(app).put(path)).send(body),
    del: (path: string) => auth(request(app).delete(path)),
  };
}

/** The seed centre used in tests. */
export const CENTER = { lat: 37.3349, lng: -122.009 };
