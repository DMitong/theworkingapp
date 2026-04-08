import { Router } from 'express';
import { authenticate } from '../middleware/auth';
import { AuthController } from '../controllers/AuthController';

const router = Router();

// POST /api/v1/auth/register
router.post('/register', AuthController.register);

// POST /api/v1/auth/login
router.post('/login', AuthController.login);

// POST /api/v1/auth/refresh
router.post('/refresh', AuthController.refresh);

// POST /api/v1/auth/logout
router.post('/logout', authenticate, AuthController.logout);

export default router;
