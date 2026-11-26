/** Local development without a real database: in-memory MongoDB, seeded, then Gapi. */
import { MongoMemoryServer } from 'mongodb-memory-server';
import { runSeed } from '../src/db/seed/seed.js';
import { start } from '../src/server.js';

const mongo = await MongoMemoryServer.create();
console.log('✓ In-memory MongoDB started (data is temporary)');
await start(mongo.getUri('gapi'));
const r = await runSeed();
console.log(`✓ Seeded. Demo login: ${r.demoLogin.email} / ${r.demoLogin.password}`);
