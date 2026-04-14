import { Request, Response, NextFunction } from 'express';
import { ProjectService } from '../services/project/ProjectService';
import { sendSuccess, sendCreated } from '../utils/response';
import { AppError } from '../utils/AppError';

export class ProjectController {
  /**
   * POST /api/v1/projects/communities/:communityId/projects
   */
  static async submitProposal(req: Request, res: Response, next: NextFunction) {
    try {
      const { communityId } = req.params;
      const userId = (req as any).user.sub;
      const result = await ProjectService.submitProposal(communityId, userId, req.body);
      sendCreated(res, result);
    } catch (err) {
      next(err);
    }
  }

  /**
   * GET /api/v1/projects/:id
   */
  static async getDetail(req: Request, res: Response, next: NextFunction) {
    try {
      const { id } = req.params;
      const result = await ProjectService.getProject(id);
      sendSuccess(res, result);
    } catch (err) {
      next(err);
    }
  }

  /**
   * POST /api/v1/projects/:id/vote/proposal
   */
  static async voteProposal(req: Request, res: Response, next: NextFunction) {
    try {
      const { id } = req.params;
      const { upvote } = req.body;
      const userId = (req as any).user.sub;
      
      if (typeof upvote !== 'boolean') {
        throw new AppError('Upvote must be a boolean', 400);
      }

      const result = await ProjectService.castProposalVote(id, userId, upvote);
      sendSuccess(res, result);
    } catch (err) {
      next(err);
    }
  }

  /**
   * PUT /api/v1/projects/:id/award
   */
  static async awardContract(req: Request, res: Response, next: NextFunction) {
    try {
      const { id } = req.params;
      const { contractorAddress } = req.body;
      const userId = (req as any).user.sub;

      if (!contractorAddress) {
        throw new AppError('Contractor address is required', 400);
      }

      const result = await ProjectService.awardContract(id, contractorAddress, userId);
      sendSuccess(res, result);
    } catch (err) {
      next(err);
    }
  }

  /**
   * POST /api/v1/projects/:id/milestones/:n/claim
   */
  static async claimMilestone(req: Request, res: Response, next: NextFunction) {
    try {
      const { id, n } = req.params;
      const files = req.files as Express.Multer.File[];

      if (!files || files.length === 0) {
        throw new AppError('Evidence file is required', 400);
      }

      const result = await ProjectService.submitMilestoneClaim(id, parseInt(n), files);
      sendSuccess(res, result);
    } catch (err) {
      next(err);
    }
  }

  /**
   * POST /api/v1/projects/:id/milestones/:n/sign
   */
  static async signMilestone(req: Request, res: Response, next: NextFunction) {
    try {
      const { id, n } = req.params;
      const userId = (req as any).user.sub;

      const result = await ProjectService.signMilestone(id, parseInt(n), userId);
      sendSuccess(res, result);
    } catch (err) {
      next(err);
    }
  }
}
