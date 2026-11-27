import { createRemoteJWKSet, jwtVerify, type JWTVerifyGetKey } from 'jose';
import { env } from '../config/env.js';

/** Google's public keys for Firebase Auth ID tokens (cached + rotated by jose). */
const GOOGLE_KEYS_URL = 'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com';

let keys: JWTVerifyGetKey = createRemoteJWKSet(new URL(GOOGLE_KEYS_URL));

/** Tests swap in a local key set so they can sign their own tokens. */
export function setFirebaseKeysForTesting(k: JWTVerifyGetKey) {
  keys = k;
}

export interface FirebaseIdentity {
  uid: string;
  phone: string | null;
}

/**
 * Verifies a Firebase Auth ID token (the app gets it after phone sign-in) the
 * way Firebase documents: RS256, signed by Google, issued for our project.
 */
export async function verifyFirebaseIdToken(idToken: string): Promise<FirebaseIdentity> {
  const projectId = env.FIREBASE_PROJECT_ID;
  const { payload } = await jwtVerify(idToken, keys, {
    algorithms: ['RS256'],
    issuer: `https://securetoken.google.com/${projectId}`,
    audience: projectId,
  });
  if (!payload.sub) throw new Error('Token has no subject');
  const phone = typeof payload.phone_number === 'string' ? payload.phone_number : null;
  return { uid: payload.sub, phone };
}
