import { createHash, randomBytes } from 'node:crypto';
import jwt from 'jsonwebtoken';
import { env } from '../config/env.js';

/** Short-lived access token (JWT) sent as `Authorization: Bearer …`. */
export const ACCESS_TOKEN_TTL_SECONDS = 15 * 60;
/** Long-lived refresh token (random, stored hashed) used to get new access tokens. */
export const REFRESH_TOKEN_TTL_DAYS = 30;

export function signAccessToken(userId: string): string {
  return jwt.sign({ sub: userId, typ: 'access' }, env.JWT_SECRET, {
    expiresIn: ACCESS_TOKEN_TTL_SECONDS,
    issuer: 'gapi',
  });
}

export function verifyAccessToken(token: string): string {
  const payload = jwt.verify(token, env.JWT_SECRET, { issuer: 'gapi' });
  if (typeof payload === 'string' || payload.typ !== 'access' || !payload.sub) throw new Error('Invalid token');
  return payload.sub;
}

export const newRefreshToken = () => randomBytes(48).toString('base64url');

export const hashToken = (token: string) => createHash('sha256').update(token).digest('hex');
