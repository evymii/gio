import { Router } from 'express';
import { dbState, pingMongo } from '../../db/mongo.js';

const startedAt = new Date();

/** GET /health — used by the host's health check and the app's status screen. */
export const healthRouter = Router();

healthRouter.get('/', async (_req, res) => {
  const latency = await pingMongo();
  const ok = latency !== null;
  res.status(ok ? 200 : 503).json({
    data: {
      status: ok ? 'ok' : 'degraded',
      service: 'gapi',
      version: process.env.npm_package_version ?? '0.2.0',
      environment: process.env.NODE_ENV ?? 'development',
      uptimeSeconds: Math.round(process.uptime()),
      startedAt: startedAt.toISOString(),
      database: { state: dbState(), latencyMs: latency },
    },
  });
});
