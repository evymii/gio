import mongoose from 'mongoose';

const STATES = ['disconnected', 'connected', 'connecting', 'disconnecting'] as const;

export async function connectMongo(uri: string): Promise<void> {
  mongoose.set('strictQuery', true);
  await mongoose.connect(uri, { serverSelectionTimeoutMS: 10_000 });
}

export async function disconnectMongo(): Promise<void> {
  await mongoose.disconnect();
}

export function dbState(): string {
  return STATES[mongoose.connection.readyState as 0 | 1 | 2 | 3] ?? 'unknown';
}

/** Round-trip ping; latency in ms, or null if unreachable. */
export async function pingMongo(): Promise<number | null> {
  if (mongoose.connection.readyState !== 1 || !mongoose.connection.db) return null;
  const start = performance.now();
  try {
    await mongoose.connection.db.admin().ping();
    return Math.round(performance.now() - start);
  } catch {
    return null;
  }
}
