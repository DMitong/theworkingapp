import { prisma } from '../../models/prisma';
import { BlockchainService } from '../blockchain/BlockchainService';
import { IPFSService } from '../ipfs/IPFSService';
import { AppError } from '../../utils/AppError';
import { logger } from '../../utils/logger';
import { PaginationParams, paginate } from '../../utils/pagination';

export class BountyService {
  /**
   * Create a new bounty.
   */
  static async createBounty(data: any, creatorId: string) {
    const { 
      title, description, requirements, totalEscrowUsdc, 
      escrowToken, milestones, visibility 
    } = data;

    // 1. Upload metadata to IPFS
    const ipfsBountyHash = await IPFSService.uploadJSON({
      title,
      description,
      requirements,
      milestones
    }, `bounty-${Date.now()}`);

    // 2. Create DB record (pending deployment)
    const bounty = await prisma.bounty.create({
      data: {
        creatorId,
        ipfsBountyHash,
        escrowToken,
        totalEscrowUsdc: BigInt(totalEscrowUsdc),
        chainId: 8453,
        state: 'TENDERING',
        visibility: visibility || 'PLATFORM_PUBLIC',
        milestones: {
          create: milestones.map((m: any, idx: number) => ({
            index: idx,
            name: m.name,
            description: m.description,
            valueUsdc: BigInt(m.valueUsdc),
            expectedCompletionAt: new Date(m.expectedCompletionAt),
            verificationType: 'COUNCIL_ONLY', // Bounties are creator-approved (effectively council-of-one)
          }))
        }
      },
      include: { milestones: true }
    });

    // 3. Trigger on-chain deployment
    // BlockchainService.deployBounty(...) would be called here via PlatformFactory
    logger.info(`Triggering on-chain deployment for bounty ${bounty.id}`);

    return bounty;
  }

  /**
   * Submit a bid on a bounty.
   */
  static async submitBid(bountyId: string, contractorId: string, data: any) {
    const bounty = await prisma.bounty.findUnique({ where: { id: bountyId } });
    if (!bounty) throw new AppError('Bounty not found', 404);
    if (bounty.state !== 'TENDERING') throw new AppError('Bounty is not accepting bids', 400);

    const bid = await prisma.bid.create({
      data: {
        bountyId,
        contractorId,
        totalCostUsdc: BigInt(data.totalCostUsdc),
        ipfsBidDocument: data.ipfsBidDocument || '',
        proposedTimelineDays: data.proposedTimelineDays,
        methodology: data.methodology
      }
    });

    return bid;
  }

  /**
   * Select a winning bid for a bounty.
   */
  static async selectBid(bountyId: string, contractorAddress: string, creatorId: string) {
    const bounty = await prisma.bounty.findUnique({ where: { id: bountyId } });
    if (!bounty) throw new AppError('Bounty not found', 404);
    if (bounty.creatorId !== creatorId) throw new AppError('Only creator can select bid', 403);

    // Update DB
    const updated = await prisma.bounty.update({
      where: { id: bountyId },
      data: {
        selectedContractorAddress: contractorAddress,
        state: 'AWARDED'
      }
    });

    // Sync on-chain
    if (bounty.contractAddress) {
      // BlockchainService.selectBountyBid(bounty.contractAddress, contractorAddress)
    }

    return updated;
  }

  /**
   * Approve a bounty milestone completion.
   */
  static async approveMilestone(bountyId: string, milestoneIndex: number, userId: string) {
    const bounty = await prisma.bounty.findUnique({ where: { id: bountyId } });
    if (!bounty) throw new AppError('Bounty not found', 404);
    if (bounty.creatorId !== userId) throw new AppError('Only creator can approve milestones', 403);

    const milestone = await prisma.milestone.findFirst({
      where: { bountyId, index: milestoneIndex }
    });
    if (!milestone) throw new AppError('Milestone not found', 404);

    // Update DB
    await prisma.milestone.update({
      where: { id: milestone.id },
      data: { state: 'PAID', paidAt: new Date() }
    });

    // Sync on-chain (triggers payout)
    if (bounty.contractAddress) {
      // BlockchainService.approveBountyMilestone(bounty.contractAddress, milestoneIndex)
    }

    return { status: 'PAID' };
  }

  /**
   * List bounties with filters and pagination.
   */
  static async listBounties(filters: any, pagination: PaginationParams) {
    const where: any = {
      ...(filters.state && { state: filters.state }),
      ...(filters.visibility && { visibility: filters.visibility })
    };

    const [items, total] = await Promise.all([
      prisma.bounty.findMany({
        where,
        skip: pagination.skip,
        take: pagination.take,
        orderBy: { createdAt: 'desc' },
        include: { creator: { select: { handle: true } } }
      }),
      prisma.bounty.count({ where })
    ]);

    return paginate(items, total, pagination);
  }

  static async getBounty(id: string) {
    const bounty = await prisma.bounty.findUnique({
      where: { id },
      include: {
        milestones: true,
        bids: { include: { contractor: { select: { handle: true, walletAddress: true } } } },
        creator: { select: { handle: true, walletAddress: true } }
      }
    });
    if (!bounty) throw new AppError('Bounty not found', 404);
    return bounty;
  }
}
