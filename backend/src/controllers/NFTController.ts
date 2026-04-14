import { Request, Response, NextFunction } from 'express';
import { BlockchainService } from '../services/blockchain/BlockchainService';
import { prisma } from '../models/prisma';
import { sendSuccess } from '../utils/response';
import { AppError } from '../utils/AppError';

export class NFTController {
  /**
   * GET /api/v1/nft/:tokenId/metadata
   *
   * Returns dynamic ERC-721 metadata for a platform NFT.
   * This is called by OpenSea or the PlatformNFTRegistry contract.
   */
  static async getMetadata(req: Request, res: Response, next: NextFunction) {
    try {
      const tokenId = parseInt(req.params.tokenId);
      if (isNaN(tokenId)) {
        throw new AppError('Invalid token ID', 400);
      }

      // 1. Get on-chain data
      const onChainData = await BlockchainService.getNFTProfileData(tokenId);
      
      // 2. Get off-chain DB data
      const user = await prisma.user.findFirst({
        where: { tokenId: tokenId }
      });

      if (!user) {
        throw new AppError('User not found for this token', 404);
      }

      // 3. Assemble ERC-721 JSON
      const metadata = {
        name: `The Working App Identity — ${user.handle}`,
        description: `Soulbound platform identity for ${user.handle} on The Working App.`,
        image: `https://api.theworkingapp.io/v1/nft/${tokenId}/image`, // Placeholder URL
        external_url: `https://theworkingapp.io/profile/${user.handle}`,
        attributes: [
          { trait_type: 'KYC Verified', value: user.isKycVerified ? 'true' : 'false' },
          { trait_type: 'Reputation Score', value: onChainData.reputationScore },
          { trait_type: 'Projects Completed', value: onChainData.projectsCompleted },
          { trait_type: 'Projects Awarded', value: onChainData.projectsAwarded },
          { trait_type: 'Community Memberships', value: onChainData.communityCount },
          { trait_type: 'Dispute Count', value: onChainData.disputeCount }
        ]
      };

      res.json(metadata);
    } catch (err) {
      next(err);
    }
  }

  /**
   * GET /api/v1/nft/:tokenId/image
   * 
   * Placeholder for generating a dynamic SVG or returning a profile image.
   */
  static async getImage(req: Request, res: Response, next: NextFunction) {
    try {
      // In a real implementation, we might generate a dynamic SVG with the user's handle
      // For now, we return a simple JSON or a placeholder.
      res.status(200).send('SVG Image Placeholder');
    } catch (err) {
      next(err);
    }
  }
}
