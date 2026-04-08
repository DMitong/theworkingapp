import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { env } from '../config/env';
import { AppError } from '../utils/AppError';

export interface AuthenticatedRequest extends Request {
  user?: {
    id: string;
    walletAddress: string;
    handle: string;
    mode: string;
  };
}

export function authenticate(req: AuthenticatedRequest, _res: Response, next: NextFunction) {
  const header = req.headers.authorization;
  if (!header?.startsWith('Bearer ')) {
    return next(new AppError('Authentication required', 401));
  }

  const token = header.slice(7);
  try {
    const payload = jwt.verify(token, env.JWT_SECRET) as {
      sub: string;
      wallet: string;
      handle: string;
      mode: string;
    };
    req.user = { id: payload.sub, walletAddress: payload.wallet, handle: payload.handle, mode: payload.mode };
    next();
  } catch {
    next(new AppError('Invalid or expired token', 401));
  }
}

export function requireCouncil(communityId: string) {
  return async (req: AuthenticatedRequest, _res: Response, next: NextFunction) => {
    // TODO: Check that req.user is a council member of communityId
    // Query MembershipService.isCouncil(req.user.id, communityId)
    next();
  };
}
