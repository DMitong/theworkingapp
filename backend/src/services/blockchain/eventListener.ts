import { ethers } from 'ethers';
import { env } from '../../config/env';
import { logger } from '../../utils/logger';
import { prisma } from '../../models/prisma';
import { BlockchainService } from './BlockchainService';

import PlatformFactoryABI from '../../abis/PlatformFactory.json';
import ProjectContractABI from '../../abis/ProjectContract.json';
import BountyContractABI from '../../abis/BountyContract.json';

// Map on-chain uint8 state to Prisma enum
const PROJECT_STATE_MAP: Record<number, string> = {
  0: 'PROPOSED',
  1: 'COUNCIL_REVIEW',
  2: 'TENDERING',
  3: 'AWARDED',
  4: 'ACTIVE',
  5: 'MILESTONE_UNDER_REVIEW',
  6: 'MILESTONE_PAID',
  7: 'COMPLETION_VOTE',
  8: 'COMPLETED',
  9: 'DISPUTED',
  10: 'EXPIRED',
  11: 'CLOSED',
};

/**
 * BlockchainEventListener
 *
 * Listens for on-chain events from deployed contracts and:
 * 1. Updates the PostgreSQL database (via Prisma) to reflect new contract state
 * 2. Emits Socket.IO events to connected frontend clients for real-time updates
 */
export class BlockchainEventListener {
  private static provider: ethers.JsonRpcProvider;
  // Lazy-import io to avoid circular dependency at module load time
  private static getIO() {
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    return require('../../index').io;
  }

  static async start() {
    this.provider = new ethers.JsonRpcProvider(env.PRIMARY_RPC_URL);

    if (!env.PLATFORM_FACTORY_ADDRESS) {
      logger.warn('PLATFORM_FACTORY_ADDRESS not set — event listener skipped');
      return;
    }

    await this.listenToFactory();
    await this.reattachActiveProjects();
    await this.reattachActiveBounties();
    logger.info('Event listener active on factory:', env.PLATFORM_FACTORY_ADDRESS);
  }

  // ── Factory Events ──────────────────────────────────────────────

  private static async listenToFactory() {
    const factory = new ethers.Contract(
      env.PLATFORM_FACTORY_ADDRESS!,
      PlatformFactoryABI.abi,
      this.provider,
    );

    factory.on('CommunityDeployed', async (registryAddress: string, founder: string, name: string) => {
      logger.info(`CommunityDeployed: ${name} at ${registryAddress}`);

      try {
        // Find the community record that was created with contractAddress = null
        // and update it with the confirmed on-chain address
        const community = await prisma.community.findFirst({
          where: { name, contractAddress: null },
          orderBy: { createdAt: 'desc' },
        });

        if (community) {
          await prisma.community.update({
            where: { id: community.id },
            data: { contractAddress: registryAddress },
          });
          logger.info(`Community ${community.id} updated with contract address ${registryAddress}`);
        }
      } catch (error) {
        logger.error('Failed to update community record on CommunityDeployed', { error });
      }

      this.getIO().emit('community:deployed', { registryAddress, founder, name });
    });

    factory.on('BountyDeployed', async (bountyContract: string, creator: string) => {
      logger.info(`BountyDeployed at ${bountyContract} by ${creator}`);

      try {
        // Find the bounty record with no contract address from this creator
        const user = await prisma.user.findUnique({ where: { walletAddress: creator } });
        if (user) {
          const bounty = await prisma.bounty.findFirst({
            where: { creatorId: user.id, contractAddress: null },
            orderBy: { createdAt: 'desc' },
          });

          if (bounty) {
            await prisma.bounty.update({
              where: { id: bounty.id },
              data: { contractAddress: bountyContract },
            });
            logger.info(`Bounty ${bounty.id} updated with contract address ${bountyContract}`);
          }
        }
      } catch (error) {
        logger.error('Failed to update bounty record on BountyDeployed', { error });
      }

      this.getIO().emit('bounty:deployed', { bountyContract, creator });
    });
  }

  // ── Re-attach Active Projects on Startup ────────────────────────

  private static async reattachActiveProjects() {
    try {
      const activeProjects = await prisma.project.findMany({
        where: {
          state: { notIn: ['COMPLETED', 'CLOSED', 'EXPIRED'] },
          contractAddress: { not: null },
        },
        select: { id: true, contractAddress: true, communityId: true },
      });

      for (const project of activeProjects) {
        if (project.contractAddress) {
          await this.listenToProject(project.contractAddress, project.id, project.communityId);
        }
      }
logger.info(`Re-attached event listeners for ${activeProjects.length} active projects`);
} catch (error) {
logger.error('Failed to re-attach active project listeners', { error });
}
}

private static async reattachActiveBounties() {
try {
const activeBounties = await prisma.bounty.findMany({
  where: {
    state: { notIn: ['COMPLETED', 'CLOSED', 'EXPIRED'] },
    contractAddress: { not: null },
  },
  select: { id: true, contractAddress: true },
});

for (const bounty of activeBounties) {
  if (bounty.contractAddress) {
    await this.listenToBounty(bounty.contractAddress, bounty.id);
  }
}

logger.info(`Re-attached event listeners for ${activeBounties.length} active bounties`);
} catch (error) {
logger.error('Failed to re-attach active bounty listeners', { error });
}
}

// ── Project Events ──────────────────────────────────────────────

...
  static async listenToProject(
    projectContractAddress: string,
    projectId: string,
    communityId: string,
  ) {
    const contract = new ethers.Contract(
      projectContractAddress,
      ProjectContractABI.abi,
      this.provider,
    );
    const io = this.getIO();

    contract.on('StateTransition', async (_from: number, to: number) => {
      const newState = PROJECT_STATE_MAP[Number(to)];
      logger.info(`Project ${projectId} state -> ${newState}`);

      try {
        await prisma.project.update({
          where: { id: projectId },
          data: { state: newState },
        });
      } catch (error) {
        logger.error('Failed to update project state in DB', { projectId, error });
      }

      io.to(`project:${projectId}`).emit('project:state', { projectId, state: newState });
    });

    contract.on('ProposalVoteCast', async (voter: string, upvote: boolean, upvotes: bigint, downvotes: bigint) => {
      try {
        await prisma.project.update({
          where: { id: projectId },
          data: {
            upvoteCount: Number(upvotes),
            downvoteCount: Number(downvotes),
          },
        });
      } catch (error) {
        logger.error('Failed to update vote counts', { projectId, error });
      }

      io.to(`community:${communityId}`).emit('project:votes', {
        projectId,
        upvotes: Number(upvotes),
        downvotes: Number(downvotes),
      });
    });

    contract.on('ContractAwarded', async (contractor: string, totalValue: bigint) => {
      logger.info(`Project ${projectId} awarded to ${contractor}, value=${totalValue}`);

      try {
        await prisma.project.update({
          where: { id: projectId },
          data: {
            awardedContractor: contractor,
            totalEscrowUsdc: totalValue,
            state: 'AWARDED',
          },
        });
      } catch (error) {
        logger.error('Failed to update awarded contractor', { projectId, error });
      }

      io.to(`project:${projectId}`).emit('project:awarded', {
        projectId,
        contractor,
        totalValue: totalValue.toString(),
      });
    });

    contract.on('MilestonePaid', async (milestoneIndex: number, contractor: string, amount: bigint) => {
      const idx = Number(milestoneIndex);
      logger.info(`Milestone ${idx} paid: ${amount} to ${contractor}`);

      try {
        const milestone = await prisma.milestone.findFirst({
          where: { projectId, index: idx },
        });

        if (milestone) {
          await prisma.milestone.update({
            where: { id: milestone.id },
            data: { state: 'PAID', paidAt: new Date() },
          });
        }
      } catch (error) {
        logger.error('Failed to update milestone state', { projectId, milestoneIndex: idx, error });
      }

      io.to(`project:${projectId}`).emit('project:milestone-paid', {
        projectId,
        milestoneIndex: idx,
        amount: amount.toString(),
      });
    });

    contract.on('CompletionVoteOpened', async () => {
      logger.info(`Completion vote opened for project ${projectId}`);
      io.to(`project:${projectId}`).emit('project:completion-vote-opened', { projectId });
      io.to(`community:${communityId}`).emit('community:completion-vote', { projectId });
    });

    contract.on('DisputeRaised', async (raisedBy: string, reason: string) => {
      logger.warn(`Dispute raised on project ${projectId} by ${raisedBy}: ${reason}`);

      try {
        await prisma.project.update({
          where: { id: projectId },
          data: {
            state: 'DISPUTED',
            disputeReason: reason,
          },
        });
      } catch (error) {
        logger.error('Failed to update project dispute in DB', { projectId, error });
      }

      io.to(`project:${projectId}`).emit('project:disputed', { projectId, raisedBy, reason });
    });

    contract.on('MediationRulingExecuted', async (ruling: unknown) => {
      logger.info(`Mediation ruling executed for project ${projectId}`);

      try {
        await prisma.project.update({
          where: { id: projectId },
          data: { state: 'COMPLETED' },
        });

        // Update community stats
        await prisma.community.update({
          where: { id: communityId },
          data: { completedProjectCount: { increment: 1 } },
        });
      } catch (error) {
        logger.error('Failed to update mediation ruling in DB', { projectId, error });
      }

      io.to(`project:${projectId}`).emit('project:mediation-resolved', { projectId });
    });

    logger.info(`Listening to project events: ${projectContractAddress} (${projectId})`);
  }

  static async listenToBounty(
    bountyContractAddress: string,
    bountyId: string,
  ) {
    const contract = new ethers.Contract(
      bountyContractAddress,
      BountyContractABI.abi,
      this.provider,
    );
    const io = this.getIO();

    contract.on('StateTransition', async (_from: number, to: number) => {
      const newState = PROJECT_STATE_MAP[Number(to)];
      logger.info(`Bounty ${bountyId} state -> ${newState}`);

      try {
        await prisma.bounty.update({
          where: { id: bountyId },
          data: { state: newState as any },
        });
      } catch (error) {
        logger.error('Failed to update bounty state in DB', { bountyId, error });
      }

      io.to(`bounty:${bountyId}`).emit('bounty:state', { bountyId, state: newState });
    });

    contract.on('BidSelected', async (contractor: string) => {
      logger.info(`Bounty ${bountyId} awarded to ${contractor}`);

      try {
        await prisma.bounty.update({
          where: { id: bountyId },
          data: {
            selectedContractorAddress: contractor,
            state: 'AWARDED',
          },
        });
      } catch (error) {
        logger.error('Failed to update awarded contractor for bounty', { bountyId, error });
      }

      io.to(`bounty:${bountyId}`).emit('bounty:awarded', { bountyId, contractor });
    });

    contract.on('MilestonePaid', async (milestoneIndex: number, contractor: string, amount: bigint) => {
      const idx = Number(milestoneIndex);
      logger.info(`Bounty Milestone ${idx} paid: ${amount} to ${contractor}`);

      try {
        const milestone = await prisma.milestone.findFirst({
          where: { bountyId, index: idx },
        });

        if (milestone) {
          await prisma.milestone.update({
            where: { id: milestone.id },
            data: { state: 'PAID', paidAt: new Date() },
          });
        }
      } catch (error) {
        logger.error('Failed to update bounty milestone state', { bountyId, milestoneIndex: idx, error });
      }

      io.to(`bounty:${bountyId}`).emit('bounty:milestone-paid', {
        bountyId,
        milestoneIndex: idx,
        amount: amount.toString(),
      });
    });

    logger.info(`Listening to bounty events: ${bountyContractAddress} (${bountyId})`);
  }
}
