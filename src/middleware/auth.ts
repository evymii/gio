import type { RequestHandler } from 'express';
import { verifyAccessToken } from '../lib/tokens.js';
import { ApiError } from '../utils/ApiError.js';

/** Requires a valid access token; sets `req.userId`. */
export const requireAuth: RequestHandler = (req, _res, next) => {
  const header = req.headers.authorization ?? '';
  const [scheme, token] = header.split(' ');
  if (scheme !== 'Bearer' || !token) return next(ApiError.unauthorized());
  try {
    req.userId = verifyAccessToken(token);
    next();
  } catch {
    next(new ApiError(401, 'TOKEN_INVALID', 'Session expired — please refresh or log in again'));
  }
};
