import { Router } from 'express';
import { authenticate } from '../middleware/auth';
import { CommunityController } from '../controllers/CommunityController';

const router = Router();

// GET /api/v1/communities/search
router.get('/search', CommunityController.search);

// POST /api/v1/communities
router.post('/', authenticate, CommunityController.create);

// GET /api/v1/communities/:id
router.get('/:id', CommunityController.getProfile);

// POST /api/v1/communities/:id/membership/apply
router.post('/:id/membership/apply', authenticate, CommunityController.apply);

export default router;
