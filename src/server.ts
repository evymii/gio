import { pathToFileURL } from 'node:url';
import { createApp } from './app.js';
import { env } from './config/env.js';
import { connectMongo, disconnectMongo } from './db/mongo.js';

/** Starts the HTTP server. `mongoUri` overrides MONGODB_URI (used by dev:memory). */
export async function start(mongoUri = env.MONGODB_URI) {
  if (!mongoUri) throw new Error('MONGODB_URI is not set. Copy .env.example to .env, or run `npm run dev:memory`.');
  await connectMongo(mongoUri);
  console.log('✓ MongoDB connected');

  const app = createApp({ corsOrigins: env.CORS_ORIGINS, logRequests: env.NODE_ENV !== 'test' });
  const server = app.listen(env.PORT, '0.0.0.0', () => {
    console.log(`✓ Gapi listening on http://localhost:${env.PORT} (${env.NODE_ENV})`);
  });

  const shutdown = (signal: string) => {
    console.log(`${signal} received — shutting down`);
    server.close(async () => {
      await disconnectMongo();
      process.exit(0);
    });
    setTimeout(() => process.exit(1), 10_000).unref();
  };
  process.on('SIGTERM', () => shutdown('SIGTERM'));
  process.on('SIGINT', () => shutdown('SIGINT'));
  return server;
}

const isEntry = !!process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href;
if (isEntry) {
  start().catch((err) => {
    console.error('✗ Failed to start:', err.message);
    process.exit(1);
  });
}
