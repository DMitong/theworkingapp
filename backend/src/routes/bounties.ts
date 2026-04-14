import { Router } from 'express';
import { authenticate } from '../middleware/auth';
import { BountyController } from '../controllers/BountyController';

const router = Router();

// POST /api/v1/bounties
router.post('/', authenticate, BountyController.create);

// GET /api/v1/bounties
router.get('/', authenticate, BountyController.list);

// GET /api/v1/bounties/:id
router.get('/:id', authenticate, BountyController.getDetail);

// POST /api/v1/bounties/:id/bids
router.post('/:id/bids', authenticate, BountyController.submitBid);

// PUT /api/v1/bounties/:id/select
router.put('/:id/select', authenticate, BountyController.selectBid);

// POST /api/v1/bounties/:id/milestones/:n/approve
router.post('/:id/milestones/:n/approve', authenticate, BountyController.approveMilestone);

export default router;
