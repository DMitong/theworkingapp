import { Request, Response, NextFunction } from 'express';
import { AuthService } from '../services/auth/AuthService';
import { sendSuccess, sendCreated } from '../utils/response';
import { AppError } from '../utils/AppError';

/**
 * AuthController
 *
 * Implements registration, login, token refresh and logout.
 */
export class AuthController {
  /**
   * POST /api/v1/auth/register
   */
  static async register(req: Request, res: Response, next: NextFunction) {
    try {
      const { email, password, handle } = req.body;

      if (!email || !password || !handle) {
        throw new AppError('Missing required fields: email, password, handle', 400);
      }

      const result = await AuthService.register({ email, password, handle });
      
      sendCreated(res, result);
    } catch (err) {
      next(err);
    }
  }

  /**
   * POST /api/v1/auth/login
   */
  static async login(req: Request, res: Response, next: NextFunction) {
    try {
      const { email, password } = req.body;

      if (!email || !password) {
        throw new AppError('Missing email or password', 400);
      }

      const result = await AuthService.login({ email, password });
      
      sendSuccess(res, result);
    } catch (err) {
      next(err);
    }
  }

  /**
   * POST /api/v1/auth/refresh
   */
  static async refresh(req: Request, res: Response, next: NextFunction) {
    try {
      const { refreshToken } = req.body;

      if (!refreshToken) {
        throw new AppError('Refresh token required', 400);
      }

      const result = await AuthService.refresh(refreshToken);
      
      sendSuccess(res, result);
    } catch (err) {
      next(err);
    }
  }

  /**
   * POST /api/v1/auth/logout
   */
  static async logout(_req: Request, res: Response, next: NextFunction) {
    try {
      // TODO: Invalidate refresh token in Redis
      sendSuccess(res, { message: 'Successfully logged out' });
    } catch (err) {
      next(err);
    }
  }
}
