import { Router } from 'express';
import { authenticate } from '../middleware/auth';
import { uploadMiddleware } from '../middleware/upload';
import { ProjectController } from '../controllers/ProjectController';

const router = Router();

// POST /api/v1/projects/communities/:communityId/projects
router.post('/communities/:communityId/projects', authenticate, ProjectController.submitProposal);

// GET /api/v1/projects/:id
router.get('/:id', ProjectController.getDetail);

// POST /api/v1/projects/:id/vote/proposal
router.post('/:id/vote/proposal', authenticate, ProjectController.voteProposal);

// PUT /api/v1/projects/:id/award
router.put('/:id/award', authenticate, ProjectController.awardContract);

// POST /api/v1/projects/:id/milestones/:n/claim
router.post('/:id/milestones/:n/claim', authenticate, uploadMiddleware.array('evidence', 5), ProjectController.claimMilestone);

// POST /api/v1/projects/:id/milestones/:n/sign
router.post('/:id/milestones/:n/sign', authenticate, ProjectController.signMilestone);

export default router;
