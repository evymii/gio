import 'dotenv/config';
import { z } from 'zod';

const DEV_JWT_SECRET = 'dev-only-insecure-secret-change-me-0123456789';

/** All configuration comes from environment variables, validated once at startup. */
const EnvSchema = z
  .object({
    NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
    PORT: z.coerce.number().int().positive().default(8080),
    MONGODB_URI: z.string().min(1).optional(),
    JWT_SECRET: z.string().min(32, 'JWT_SECRET must be at least 32 characters').optional(),
    LOCATION_TTL_DAYS: z.coerce.number().int().min(1).max(90).default(7),
    CORS_ORIGINS: z.string().default('*'),
    SEED_LAT: z.coerce.number().min(-90).max(90).default(37.3349),
    SEED_LNG: z.coerce.number().min(-180).max(180).default(-122.009),
    SEED_PASSWORD: z.string().min(6).default('campus123'),
  })
  .transform((e, ctx) => {
    if (!e.JWT_SECRET && e.NODE_ENV === 'production') {
      ctx.addIssue({ code: 'custom', path: ['JWT_SECRET'], message: 'JWT_SECRET is required in production' });
    }
    return { ...e, JWT_SECRET: e.JWT_SECRET ?? DEV_JWT_SECRET };
  });

export type Env = z.infer<typeof EnvSchema>;

export function loadEnv(source: NodeJS.ProcessEnv = process.env): Env {
  const parsed = EnvSchema.safeParse(source);
  if (!parsed.success) {
    const issues = parsed.error.issues.map((i) => `  - ${i.path.join('.')}: ${i.message}`).join('\n');
    throw new Error(`Invalid environment configuration:\n${issues}`);
  }
  if (parsed.data.JWT_SECRET === DEV_JWT_SECRET && parsed.data.NODE_ENV === 'development') {
    console.warn('⚠ JWT_SECRET not set — using an insecure development secret');
  }
  return parsed.data;
}

export const env = loadEnv();
