import cors from 'cors';
import express from 'express';
import rateLimit from 'express-rate-limit';
import helmet from 'helmet';
import { errorHandler, notFound } from './middleware/errorHandler.js';
import { requestLogger } from './middleware/requestLogger.js';
import { authRouter } from './modules/auth/auth.routes.js';
import { checkinsRouter } from './modules/checkins/checkin.routes.js';
import { dashboardRouter } from './modules/dashboard/dashboard.routes.js';
import { devicesRouter } from './modules/devices/device.routes.js';
import { eventsRouter } from './modules/events/event.routes.js';
import { friendsRouter } from './modules/friends/friend.routes.js';
import { healthRouter } from './modules/health/health.routes.js';
import { leaderboardsRouter } from './modules/leaderboards/leaderboard.routes.js';
import { locationsRouter } from './modules/locations/location.routes.js';
import { questsRouter } from './modules/quests/quest.routes.js';
import { regionsRouter } from './modules/regions/region.routes.js';
import { inventoryRouter, rewardsRouter } from './modules/rewards/reward.routes.js';
import { spotsRouter } from './modules/spots/spot.routes.js';
import { usersRouter } from './modules/users/user.routes.js';

export interface AppOptions {
  corsOrigins?: string;
  logRequests?: boolean;
  rateLimit?: boolean;
}

/** Builds the Express app without starting a server (tests use it directly). */
export function createApp({ corsOrigins = '*', logRequests = true, rateLimit: limit = true }: AppOptions = {}) {
  const app = express();
  app.set('trust proxy', 1);
  app.disable('x-powered-by');
  app.use(helmet());
  app.use(cors({ origin: corsOrigins === '*' ? true : corsOrigins.split(',').map((s) => s.trim()) }));
  app.use(express.json({ limit: '100kb' }));
  if (logRequests) app.use(requestLogger);

  app.get('/', (_req, res) => res.json({ data: { service: 'gapi', health: '/health', api: '/api/v1' } }));
  app.use('/health', healthRouter);

  const api = express.Router();
  if (limit) api.use(rateLimit({ windowMs: 60_000, limit: 300, standardHeaders: 'draft-8', legacyHeaders: false }));
  api.use('/auth', authRouter);
  api.use('/users', usersRouter);
  api.use('/devices', devicesRouter);
  api.use('/locations', locationsRouter);
  api.use('/friends', friendsRouter);
  api.use('/spots', spotsRouter);
  api.use('/checkins', checkinsRouter);
  api.use('/quests', questsRouter);
  api.use('/rewards', rewardsRouter);
  api.use('/inventory', inventoryRouter);
  api.use('/leaderboards', leaderboardsRouter);
  api.use('/regions', regionsRouter);
  api.use('/events', eventsRouter);
  api.use('/dashboard', dashboardRouter);
  app.use('/api/v1', api);

  app.use(notFound);
  app.use(errorHandler);
  return app;
}
