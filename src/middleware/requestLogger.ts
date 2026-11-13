import type { RequestHandler } from 'express';

/** One concise line per request (never logs bodies — they contain passwords/locations). */
export const requestLogger: RequestHandler = (req, res, next) => {
  const start = performance.now();
  res.on('finish', () => {
    console.log(`${req.method} ${req.originalUrl.split('?')[0]} → ${res.statusCode} (${(performance.now() - start).toFixed(1)} ms)`);
  });
  next();
};
