import { ethers } from 'ethers';
import { env } from '../../config/env';
import { logger } from '../../utils/logger';
import { io } from '../../index';

/**
 * BlockchainEventListener
 *
 * Listens for on-chain events from deployed contracts and:
 * 1. Updates the PostgreSQL database (via Prisma) to reflect new contract state
 * 2. Emits Socket.IO events to connected frontend clients for real-time updates
 *
 * BUILD GUIDE:
 * ─────────────────────────────────────────────────────────────
 * Event → DB update → Socket.IO emit pattern for each event:
 *
 * StateTransition(from, to)
 *   → Update projects.state in DB
 *   → emit to room `project:{projectId}`: { type: 'STATE_CHANGE', state }
 *
 * ProposalVoteCast(voter, upvote, upvotes, downvotes)
 *   → Update projects.upvoteCount / downvoteCount
 *   → emit to room `community:{communityId}`: { type: 'VOTE_UPDATE', counts }
 *
 * ContractAwarded(contractor, totalValue)
 *   → Update projects.awardedContractor, projects.state
 *   → Notify contractor via email
 *
 * MilestonePaid(milestoneIndex, contractor, amount)
 *   → Update milestone.state = PAID
 *   → emit to room `project:{projectId}`: { type: 'MILESTONE_PAID', milestoneIndex }
 *
 * ProjectCompleted(contractor, totalPaid)
 *   → Update project.state = COMPLETED
 *   → Update contractor NFT reputation (via BlockchainService.getNFTData)
 *   → Send completion notifications
 *
 * DisputeRaised(raisedBy, reason)
 *   → Update project.state = DISPUTED
 *   → Alert platform mediation team
 *
 * CommunityDeployed(registry, founder, name) — on Factory
 *   → Create community record in DB with contract address
 *
 * BountyDeployed(bountyContract, creator) — on Factory
 *   → Create bounty record in DB
 *
 * For production: consider using The Graph for indexing instead of polling.
 * The Graph subgraph should be defined in /subgraph (Phase 2 addition).
 * ─────────────────────────────────────────────────────────────
 */
export class BlockchainEventListener {
  private static provider: ethers.JsonRpcProvider;

  static async start() {
    this.provider = new ethers.JsonRpcProvider(env.PRIMARY_RPC_URL);

    if (!env.PLATFORM_FACTORY_ADDRESS) {
      logger.warn('PLATFORM_FACTORY_ADDRESS not set — event listener skipped');
      return;
    }

    await this.listenToFactory();
    logger.info('Event listener active on factory:', env.PLATFORM_FACTORY_ADDRESS);
  }

  private static async listenToFactory() {
    const factoryABI = [
      'event CommunityDeployed(address indexed communityRegistry, address indexed founder, string name)',
      'event BountyDeployed(address indexed bountyContract, address indexed creator)',
    ];

    const factory = new ethers.Contract(env.PLATFORM_FACTORY_ADDRESS!, factoryABI, this.provider);

    factory.on('CommunityDeployed', async (registryAddress, founder, name) => {
      logger.info(`CommunityDeployed: ${name} at ${registryAddress}`);
      // TODO: Update community record in DB with confirmed contract address
      io.emit('community:deployed', { registryAddress, founder, name });
    });

    factory.on('BountyDeployed', async (bountyContract, creator) => {
      logger.info(`BountyDeployed at ${bountyContract} by ${creator}`);
      // TODO: Update bounty record in DB with confirmed contract address
      io.emit('bounty:deployed', { bountyContract, creator });
    });
  }

  /**
   * Attach event listeners to a specific ProjectContract.
   * Called when a new project is deployed or when the server restarts
   * (re-attach to all active project contracts from DB).
   *
   * TODO: Implement. Query all projects with state != COMPLETED from DB on startup
   * and call this for each one.
   */
  static async listenToProject(projectContractAddress: string, projectId: string, communityId: string) {
    const projectABI = [
      'event StateTransition(uint8 from, uint8 to)',
      'event ProposalVoteCast(address indexed voter, bool upvote, uint256 upvotes, uint256 downvotes)',
      'event ContractAwarded(address indexed contractor, uint256 totalValue)',
      'event MilestonePaid(uint8 indexed milestoneIndex, address indexed contractor, uint256 amount)',
      'event ProjectCompleted(address indexed contractor, uint256 totalPaid)',
      'event DisputeRaised(address indexed raisedBy, string reason)',
      'event MediationRulingExecuted((address contractor, address funder, uint256 contractorAmount, uint256 funderRefund, string rulingIpfsHash))',
    ];

    const contract = new ethers.Contract(projectContractAddress, projectABI, this.provider);

    contract.on('StateTransition', async (_from, to) => {
      logger.info(`Project ${projectId} state → ${to}`);
      // TODO: Map uint8 to ProjectState enum, update DB, emit to room
      io.to(`project:${projectId}`).emit('project:state', { projectId, state: Number(to) });
    });

    contract.on('ProposalVoteCast', async (_voter, _upvote, upvotes, downvotes) => {
      // TODO: Update DB vote counts
      io.to(`community:${communityId}`).emit('project:votes', {
        projectId,
        upvotes: Number(upvotes),
        downvotes: Number(downvotes),
      });
    });

    contract.on('MilestonePaid', async (milestoneIndex, contractor, amount) => {
      logger.info(`Milestone ${milestoneIndex} paid: ${amount} to ${contractor}`);
      // TODO: Update milestone state in DB
      io.to(`project:${projectId}`).emit('project:milestone-paid', {
        projectId,
        milestoneIndex: Number(milestoneIndex),
        amount: amount.toString(),
      });
    });

    contract.on('ProjectCompleted', async (contractor, totalPaid) => {
      logger.info(`Project ${projectId} completed. Total paid: ${totalPaid}`);
      // TODO: Update DB, update contractor NFT reputation score
      io.to(`project:${projectId}`).emit('project:completed', { projectId, contractor });
      io.to(`community:${communityId}`).emit('community:project-completed', { projectId });
    });

    contract.on('DisputeRaised', async (raisedBy, reason) => {
      logger.warn(`Dispute raised on project ${projectId} by ${raisedBy}: ${reason}`);
      // TODO: Update DB, alert mediation team via email/Slack
      io.to(`project:${projectId}`).emit('project:disputed', { projectId, raisedBy });
    });
  }
}
