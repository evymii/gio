import type { ErrorRequestHandler, RequestHandler } from 'express';
import mongoose from 'mongoose';
import { ApiError } from '../utils/ApiError.js';

export const notFound: RequestHandler = (req, _res, next) => {
  next(ApiError.notFound(`Route ${req.method} ${req.path} not found`));
};

/** Turns any thrown error into `{ error: { code, message, details? } }`. */
export const errorHandler: ErrorRequestHandler = (err, _req, res, _next) => {
  let e: ApiError;
  if (err instanceof ApiError) e = err;
  else if (err instanceof mongoose.Error.CastError) e = ApiError.badRequest(`Invalid ${err.path}`);
  else if (err instanceof mongoose.Error.ValidationError) e = ApiError.badRequest(err.message);
  else if (err?.type === 'entity.parse.failed') e = ApiError.badRequest('Malformed JSON body');
  else if (err?.code === 11000) e = ApiError.conflict('Duplicate value');
  else {
    console.error(err);
    e = new ApiError(500, 'INTERNAL', 'Something went wrong');
  }
  res.status(e.status).json({ error: { code: e.code, message: e.message, ...(e.details ? { details: e.details } : {}) } });
};
