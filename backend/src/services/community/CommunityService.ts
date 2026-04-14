import { prisma } from '../../models/prisma';
import { BlockchainService } from '../blockchain/BlockchainService';
import { AppError } from '../../utils/AppError';
import { logger } from '../../utils/logger';
import { PaginationParams, paginate } from '../../utils/pagination';

export class CommunityService {
  /**
   * Create a new community.
   * Logic:
   * 1. Save community record to DB (with contractAddress: null)
   * 2. Call on-chain deployCommunity() via BlockchainService
   * 3. Return community record (event listener will update contractAddress)
   */
  static async createCommunity(data: any, founderId: string) {
    const { 
      name, type, description, scope,
      councilSigners, councilThreshold,
      governanceParams 
    } = data;

    // 1. Create DB record first (pending deployment)
    const community = await prisma.community.create({
      data: {
        name,
        type,
        description,
        scope,
        chainId: 8453, // Defaulting to Base for Phase 1
        councilSigners,
        councilThreshold,
        proposalApprovalThresholdBps: governanceParams.proposalApprovalThreshold,
        proposalVotingWindowSecs: governanceParams.proposalVotingWindow,
        completionVoteWindowSecs: governanceParams.completionVoteWindow,
        bidWindowSecs: governanceParams.bidWindow,
        councilReviewWindowSecs: governanceParams.councilReviewWindow,
        tier1ThresholdUsdc: governanceParams.tier1Threshold,
        tier2ThresholdUsdc: governanceParams.tier2Threshold,
        minMembers: governanceParams.minMembers,
        portionGrantMaxPct: governanceParams.portionGrantMaxPercent,
        verificationMode: governanceParams.verificationMode,
        // Membership for the founder
        memberships: {
          create: {
            userId: founderId,
            role: 'COUNCIL',
          }
        }
      },
    });

    // 2. Trigger on-chain deployment
    BlockchainService.deployCommunity({
      name,
      councilSigners,
      councilThreshold,
      governanceParams: {
        ...governanceParams,
        tier1Threshold: BigInt(governanceParams.tier1Threshold),
        tier2Threshold: BigInt(governanceParams.tier2Threshold),
      }
    })
    .then(async ({ txHash }) => {
      logger.info(`Community ${community.id} deployment tx: ${txHash}`);
    })
    .catch((err) => {
      logger.error(`Failed to deploy community ${community.id} on-chain`, err);
    });

    return community;
  }

  /**
   * Apply for membership in a community.
   */
  static async applyForMembership(communityId: string, userId: string) {
    const community = await prisma.community.findUnique({ where: { id: communityId } });
    if (!community) throw new AppError('Community not found', 404);

    const existing = await prisma.membership.findUnique({
      where: { userId_communityId: { userId, communityId } }
    });
    if (existing) throw new AppError('Already a member', 400);

    // For OPEN mode, we auto-approve (simpler for v1)
    const isActive = community.verificationMode === 'OPEN';

    const membership = await prisma.membership.create({
      data: {
        userId,
        communityId,
        isActive,
        role: 'MEMBER'
      }
    });

    if (isActive) {
      await prisma.community.update({
        where: { id: communityId },
        data: { memberCount: { increment: 1 } }
      });
    }

    return membership;
  }

  /**
   * Search communities with filters and pagination.
   */
  static async searchCommunities(query: string, filters: any, pagination: PaginationParams) {
    const where: any = {
      isActive: true,
      ...(query && {
        OR: [
          { name: { contains: query, mode: 'insensitive' } },
          { description: { contains: query, mode: 'insensitive' } }
        ]
      }),
      ...(filters.type && { type: filters.type })
    };

    const [items, total] = await Promise.all([
      prisma.community.findMany({
        where,
        skip: pagination.skip,
        take: pagination.take,
        orderBy: { memberCount: 'desc' }
      }),
      prisma.community.count({ where })
    ]);

    return paginate(items, total, pagination);
  }

  /**
   * Get community by ID or contract address.
   */
  static async getCommunity(idOrAddress: string) {
    const community = await prisma.community.findFirst({
      where: {
        OR: [
          { id: idOrAddress },
          { contractAddress: idOrAddress }
        ]
      },
      include: {
        _count: {
          select: { members: true, projects: true }
        }
      }
    });

    if (!community) throw new AppError('Community not found', 404);
    return community;
  }
}
