import { Request, Response, NextFunction } from 'express';
import { BountyService } from '../services/bounty/BountyService';
import { sendSuccess, sendCreated } from '../utils/response';
import { getPaginationParams } from '../utils/pagination';
import { AppError } from '../utils/AppError';

export class BountyController {
  /**
   * POST /api/v1/bounties
   */
  static async create(req: Request, res: Response, next: NextFunction) {
    try {
      const creatorId = (req as any).user.sub;
      const result = await BountyService.createBounty(req.body, creatorId);
      sendCreated(res, result);
    } catch (err) {
      next(err);
    }
  }

  /**
   * GET /api/v1/bounties
   */
  static async list(req: Request, res: Response, next: NextFunction) {
    try {
      const { state, visibility } = req.query;
      const pagination = getPaginationParams(req);
      const result = await BountyService.listBounties(
        { state, visibility },
        pagination
      );
      sendSuccess(res, result);
    } catch (err) {
      next(err);
    }
  }

  /**
   * GET /api/v1/bounties/:id
   */
  static async getDetail(req: Request, res: Response, next: NextFunction) {
    try {
      const { id } = req.params;
      const result = await BountyService.getBounty(id);
      sendSuccess(res, result);
    } catch (err) {
      next(err);
    }
  }

  /**
   * POST /api/v1/bounties/:id/bids
   */
  static async submitBid(req: Request, res: Response, next: NextFunction) {
    try {
      const { id } = req.params;
      const contractorId = (req as any).user.sub;
      const result = await BountyService.submitBid(id, contractorId, req.body);
      sendSuccess(res, result);
    } catch (err) {
      next(err);
    }
  }

  /**
   * PUT /api/v1/bounties/:id/select
   */
  static async selectBid(req: Request, res: Response, next: NextFunction) {
    try {
      const { id } = req.params;
      const { contractorAddress } = req.body;
      const creatorId = (req as any).user.sub;

      if (!contractorAddress) {
        throw new AppError('Contractor address is required', 400);
      }

      const result = await BountyService.selectBid(id, contractorAddress, creatorId);
      sendSuccess(res, result);
    } catch (err) {
      next(err);
    }
  }

  /**
   * POST /api/v1/bounties/:id/milestones/:n/approve
   */
  static async approveMilestone(req: Request, res: Response, next: NextFunction) {
    try {
      const { id, n } = req.params;
      const userId = (req as any).user.sub;
      const result = await BountyService.approveMilestone(id, parseInt(n), userId);
      sendSuccess(res, result);
    } catch (err) {
      next(err);
    }
  }
}
