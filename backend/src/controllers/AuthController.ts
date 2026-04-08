import { Request, Response, NextFunction } from 'express';
import { AppError } from '../utils/AppError';

/**
 * AuthController
 *
 * BUILD GUIDE:
 * 1. register(): Validate email + handle uniqueness. Hash password with bcrypt.
 *    Create User in DB. Call BlockchainService.mintPlatformNFT(walletAddress, handle).
 *    Create embedded wallet via MPC provider (e.g. Privy, Dynamic, or Web3Auth) for Standard Mode.
 *    Return JWT + user profile.
 *
 * 2. login(): Verify email/password. Check user exists. Sign JWT with sub=userId,
 *    wallet=walletAddress, handle, mode. Return JWT + refresh token.
 *
 * 3. refresh(): Verify refresh token. Issue new JWT.
 *
 * 4. logout(): Invalidate refresh token in Redis.
 */
export class AuthController {
  static async register(req: Request, res: Response, next: NextFunction) {
    try {
      // TODO: Implement registration
      // 1. Validate request body (email, password, handle)
      // 2. Check email + handle uniqueness
      // 3. Create embedded wallet (Standard Mode default)
      // 4. Save user to DB (Prisma)
      // 5. Mint platform NFT via BlockchainService.mintPlatformNFT()
      // 6. Send confirmation email
      // 7. Return JWT + user
      res.status(201).json({ success: true, message: 'TODO: implement registration' });
    } catch (err) {
      next(err);
    }
  }

  static async login(req: Request, res: Response, next: NextFunction) {
    try {
      // TODO: Implement login
      res.json({ success: true, message: 'TODO: implement login' });
    } catch (err) {
      next(err);
    }
  }

  static async refresh(req: Request, res: Response, next: NextFunction) {
    try {
      // TODO: Implement token refresh
      res.json({ success: true, message: 'TODO: implement refresh' });
    } catch (err) {
      next(err);
    }
  }

  static async logout(req: Request, res: Response, next: NextFunction) {
    try {
      // TODO: Invalidate refresh token in Redis
      res.json({ success: true });
    } catch (err) {
      next(err);
    }
  }
}
