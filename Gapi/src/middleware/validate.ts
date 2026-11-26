import type { RequestHandler } from 'express';
import type { ZodType } from 'zod';
import { ApiError } from '../utils/ApiError.js';

type Part = 'body' | 'query' | 'params';

/** Validates `req[part]` with zod; the parsed value goes to `res.locals[part]`. */
export const validate =
  (schema: ZodType, part: Part = 'body'): RequestHandler =>
  (req, res, next) => {
    const result = schema.safeParse(req[part] ?? {});
    if (!result.success) {
      const details = result.error.issues.map((i) => ({ path: i.path.join('.'), message: i.message }));
      return next(ApiError.badRequest('Validation failed', details));
    }
    res.locals[part] = result.data;
    next();
  };
