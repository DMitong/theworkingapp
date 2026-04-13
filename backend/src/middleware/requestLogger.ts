import { Request, Response, NextFunction } from 'express';
import { logger } from '../utils/logger';

/**
 * Logs incoming HTTP requests with method, URL, status code, and duration.
 */
export const requestLogger = (req: Request, res: Response, next: NextFunction): void => {
  const start = Date.now();

  res.on('finish', () => {
    const duration = Date.now() - start;
    logger.info(`${req.method} ${req.originalUrl} ${res.statusCode} ${duration}ms`);
  });

  next();
};
