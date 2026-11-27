import { Router } from 'express';
import rateLimit from 'express-rate-limit';
import { z } from 'zod';
import { env } from '../../config/env.js';
import { validate } from '../../middleware/validate.js';
import { authService } from './auth.service.js';

const email = z.string().trim().toLowerCase().email('Enter a valid email');
const signupSchema = z.object({
  name: z.string().trim().min(2, 'At least 2 characters').max(30, 'At most 30 characters'),
  email,
  password: z.string().min(8, 'At least 8 characters').max(128),
});
const loginSchema = z.object({ email, password: z.string().min(1, 'Required') });
const refreshSchema = z.object({ refreshToken: z.string().min(20) });
const firebaseSchema = z.object({ idToken: z.string().min(20).max(4096) });

/** Brute-force protection for credential endpoints. */
const authLimiter = rateLimit({
  windowMs: 15 * 60_000,
  limit: 20,
  standardHeaders: 'draft-8',
  legacyHeaders: false,
  skip: () => env.NODE_ENV === 'test',
});

/** /api/v1/auth — phone sign-in (Firebase), email sign up / log in, refresh, log out. */
export const authRouter = Router();
const ua = (h: unknown) => (typeof h === 'string' ? h : '');

authRouter.post('/signup', authLimiter, validate(signupSchema), async (req, res) => {
  res.status(201).json({ data: await authService.signup(res.locals.body, ua(req.headers['user-agent'])) });
});

authRouter.post('/login', authLimiter, validate(loginSchema), async (req, res) => {
  res.json({ data: await authService.login(res.locals.body, ua(req.headers['user-agent'])) });
});

authRouter.post('/firebase', authLimiter, validate(firebaseSchema), async (req, res) => {
  res.json({ data: await authService.firebase(res.locals.body.idToken, ua(req.headers['user-agent'])) });
});

authRouter.post('/refresh', validate(refreshSchema), async (req, res) => {
  res.json({ data: await authService.refresh(res.locals.body.refreshToken, ua(req.headers['user-agent'])) });
});

authRouter.post('/logout', validate(refreshSchema), async (_req, res) => {
  await authService.logout(res.locals.body.refreshToken);
  res.status(204).end();
});
