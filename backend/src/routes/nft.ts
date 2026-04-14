import { Router } from 'express';
import { NFTController } from '../controllers/NFTController';

const router = Router();

// GET /api/v1/nft/:tokenId/metadata
router.get('/:tokenId/metadata', NFTController.getMetadata);

// GET /api/v1/nft/:tokenId/image
router.get('/:tokenId/image', NFTController.getImage);

export default router;
