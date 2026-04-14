import { Request, Response, NextFunction } from 'express';
import { CommunityService } from '../services/community/CommunityService';
import { sendSuccess, sendCreated } from '../utils/response';
import { getPaginationParams } from '../utils/pagination';

export class CommunityController {
  /**
   * POST /api/v1/communities
   */
  static async create(req: Request, res: Response, next: NextFunction) {
    try {
      const founderId = (req as any).user.sub;
      const result = await CommunityService.createCommunity(req.body, founderId);
      sendCreated(res, result);
    } catch (err) {
      next(err);
    }
  }

  /**
   * GET /api/v1/communities/search
   */
  static async search(req: Request, res: Response, next: NextFunction) {
    try {
      const { q, type } = req.query;
      const pagination = getPaginationParams(req);
      const result = await CommunityService.searchCommunities(
        q as string,
        { type },
        pagination
      );
      sendSuccess(res, result);
    } catch (err) {
      next(err);
    }
  }

  /**
   * GET /api/v1/communities/:id
   */
  static async getProfile(req: Request, res: Response, next: NextFunction) {
    try {
      const { id } = req.params;
      const result = await CommunityService.getCommunity(id);
      sendSuccess(res, result);
    } catch (err) {
      next(err);
    }
  }

  /**
   * POST /api/v1/communities/:id/membership/apply
   */
  static async apply(req: Request, res: Response, next: NextFunction) {
    try {
      const { id } = req.params;
      const userId = (req as any).user.sub;
      const result = await CommunityService.applyForMembership(id, userId);
      sendSuccess(res, result);
    } catch (err) {
      next(err);
    }
  }
}
