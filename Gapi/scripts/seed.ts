/**
 * Seeds the database in MONGODB_URI.
 *   npm run seed         create collections + indexes, upsert catalog, rebuild demo users
 *   npm run seed:reset   also wipe the catalog collections first
 */
import mongoose from 'mongoose';
import { env } from '../src/config/env.js';
import { connectMongo, disconnectMongo } from '../src/db/mongo.js';
import { runSeed } from '../src/db/seed/seed.js';

const reset = process.argv.includes('--reset');
if (!env.MONGODB_URI) {
  console.error('✗ MONGODB_URI is not set (see .env.example)');
  process.exit(1);
}

try {
  await connectMongo(env.MONGODB_URI);
  console.log(`✓ Connected to database "${mongoose.connection.name}"${reset ? ' — resetting catalog' : ''}`);
  const r = await runSeed({ reset });
  console.log(`✓ Seeded around ${r.center.lat.toFixed(4)}, ${r.center.lng.toFixed(4)}`);
  console.log('  Documents per collection:');
  for (const [name, n] of Object.entries(r.collections)) console.log(`    ${name.padEnd(16)} ${n}`);
  console.log(`  Demo login: ${r.demoLogin.email} / ${r.demoLogin.password}`);
} catch (err) {
  console.error('✗ Seed failed:', err instanceof Error ? err.message : err);
  process.exitCode = 1;
} finally {
  await disconnectMongo();
}
