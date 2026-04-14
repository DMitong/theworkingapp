import { prisma } from '../../models/prisma';
import { BlockchainService } from '../blockchain/BlockchainService';
import { IPFSService } from '../ipfs/IPFSService';
import { AppError } from '../../utils/AppError';
import { logger } from '../../utils/logger';
import { PaginationParams, paginate } from '../../utils/pagination';

export class ProjectService {
  /**
   * Submit a new project proposal.
   * 1. Upload metadata to IPFS.
   * 2. Call on-chain deployProject via BlockchainService.
   * 3. Save pending record in DB.
   */
  static async submitProposal(communityId: string, userId: string, data: any) {
    const { title, description, scope, budget, milestones, escrowToken } = data;

    // 1. Upload proposal metadata to IPFS
    const ipfsProposalHash = await IPFSService.uploadJSON({
      title,
      description,
      scope,
      budget,
      milestones,
    }, `proposal-${Date.now()}`);

    // 2. Create DB record (pending deployment)
    const project = await prisma.project.create({
      data: {
        communityId,
        proposerId: userId,
        ipfsProposalHash,
        escrowToken,
        chainId: 8453,
        state: 'PROPOSED',
        milestones: {
          create: milestones.map((m: any, idx: number) => ({
            index: idx,
            name: m.name,
            description: m.description,
            valueUsdc: BigInt(m.valueUsdc),
            expectedCompletionAt: new Date(m.expectedCompletionAt),
            verificationType: m.verificationType,
          }))
        }
      },
      include: { milestones: true }
    });

    // 3. Trigger on-chain deployment (via community registry)
    const community = await prisma.community.findUnique({ where: { id: communityId } });
    if (!community?.contractAddress) {
      throw new AppError('Community contract not deployed', 400);
    }

    // In a real implementation, we'd encode the proposal parameters for the contract
    // For now, we simulate the deployment trigger
    logger.info(`Triggering on-chain deployment for project ${project.id} in community ${community.contractAddress}`);
    
    // BlockchainService.deployProject(...) implementation would go here
    // The event listener will catch the deployment and update contractAddress

    return project;
  }

  /**
   * Cast a vote on a proposal.
   */
  static async castProposalVote(projectId: string, userId: string, upvote: boolean) {
    const project = await prisma.project.findUnique({ where: { id: projectId } });
    if (!project) throw new AppError('Project not found', 404);
    if (project.state !== 'PROPOSED') throw new AppError('Voting is closed', 400);

    // 1. Update DB
    await prisma.proposalVote.upsert({
      where: { projectId_userId: { projectId, userId } },
      create: { projectId, userId, upvote },
      update: { upvote }
    });

    // 2. Sync counts (denormalized for speed)
    const upvotes = await prisma.proposalVote.count({ where: { projectId, upvote: true } });
    const downvotes = await prisma.proposalVote.count({ where: { projectId, upvote: false } });

    await prisma.project.update({
      where: { id: projectId },
      data: { upvoteCount: upvotes, downvoteCount: downvotes }
    });

    // 3. Call on-chain (Standard Mode relay)
    if (project.contractAddress) {
      BlockchainService.castProposalVote(project.contractAddress, upvote)
        .catch(err => logger.error(`Failed to sync vote on-chain for ${projectId}`, err));
    }

    return { upvotes, downvotes };
  }

  /**
   * Award a contract to a contractor.
   */
  static async awardContract(projectId: string, contractorAddress: string, userId: string) {
    const project = await prisma.project.findUnique({ where: { id: projectId } });
    if (!project) throw new AppError('Project not found', 404);

    // Verify caller is council member
    const membership = await prisma.membership.findUnique({
      where: { userId_communityId: { userId, communityId: project.communityId } }
    });
    if (membership?.role !== 'COUNCIL') throw new AppError('Only council can award contracts', 403);

    // Update DB
    const updated = await prisma.project.update({
      where: { id: projectId },
      data: { 
        state: 'AWARDED',
        awardedContractor: contractorAddress
      }
    });

    // On-chain award would be triggered here via ProjectContract.awardContract()

    return updated;
  }

  /**
   * Submit a milestone completion claim.
   */
  static async submitMilestoneClaim(projectId: string, milestoneIndex: number, evidenceFiles: any[]) {
    const project = await prisma.project.findUnique({ where: { id: projectId } });
    if (!project) throw new AppError('Project not found', 404);

    // 1. Upload evidence to IPFS (assume first file for simplicity)
    const ipfsEvidence = await IPFSService.uploadFile(
      evidenceFiles[0].buffer,
      evidenceFiles[0].originalname,
      evidenceFiles[0].mimetype
    );

    // 2. Update DB
    const milestone = await prisma.milestone.findFirst({
      where: { projectId, index: milestoneIndex }
    });
    if (!milestone) throw new AppError('Milestone not found', 404);

    await prisma.milestone.update({
      where: { id: milestone.id },
      data: { 
        state: 'UNDER_REVIEW',
        ipfsEvidence
      }
    });

    await prisma.project.update({
      where: { id: projectId },
      data: { state: 'MILESTONE_UNDER_REVIEW' }
    });

    // 3. Sync on-chain
    if (project.contractAddress) {
      BlockchainService.submitMilestoneCompletion(project.contractAddress, milestoneIndex, ipfsEvidence)
        .catch(err => logger.error(`Failed to sync milestone claim on-chain for ${projectId}`, err));
    }

    return { ipfsEvidence };
  }

  /**
   * Sign off on a milestone (Council).
   */
  static async signMilestone(projectId: string, milestoneIndex: number, userId: string) {
    const project = await prisma.project.findUnique({ where: { id: projectId } });
    if (!project) throw new AppError('Project not found', 404);

    const milestone = await prisma.milestone.findFirst({
      where: { projectId, index: milestoneIndex }
    });
    if (!milestone) throw new AppError('Milestone not found', 404);

    // Record signature
    await prisma.milestoneSignature.create({
      data: {
        milestoneId: milestone.id,
        signerId: userId
      }
    });

    const signatureCount = await prisma.milestoneSignature.count({
      where: { milestoneId: milestone.id }
    });

    await prisma.milestone.update({
      where: { id: milestone.id },
      data: { signaturesReceived: signatureCount }
    });

    // If threshold met (simplifying to 1 for v1)
    if (signatureCount >= milestone.signaturesRequired) {
      // In real scenario, on-chain payout happens here
      if (project.contractAddress) {
        BlockchainService.signMilestone(project.contractAddress, milestoneIndex)
          .catch(err => logger.error(`Failed to sync milestone signature on-chain for ${projectId}`, err));
      }
    }

    return { signatureCount };
  }

  static async getProject(id: string) {
    const project = await prisma.project.findUnique({
      where: { id },
      include: {
        milestones: true,
        proposer: { select: { handle: true, walletAddress: true } },
        community: { select: { name: true, contractAddress: true } }
      }
    });
    if (!project) throw new AppError('Project not found', 404);
    return project;
  }
}
