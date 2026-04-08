import { ethers } from 'ethers';
import { env } from '../../config/env';
import { logger } from '../../utils/logger';

// ABI fragments — replace with full ABIs from contracts/out/ after forge build
const FACTORY_ABI = [
  'function mintPlatformNFT(address user, string handle) returns (uint256)',
  'function deployCommunity(string name, tuple(address[] signers, uint8 threshold) councilConfig, tuple(uint256 proposalApprovalThresholdBps, uint256 proposalVotingWindowSecs, uint256 completionVoteWindowSecs, uint256 bidWindowSecs, uint256 councilReviewWindowSecs, uint256 tier1ThresholdUsdc, uint256 tier2ThresholdUsdc, uint256 minMembers, uint8 portionGrantMaxPct, uint8 verificationMode) govParams) returns (address)',
  'function deployBounty(string ipfsBountyHash, tuple[] milestones, address escrowToken, uint8 visibility, address[] targetCommunities) returns (address)',
  'event CommunityDeployed(address indexed communityRegistry, address indexed founder, string name)',
  'event BountyDeployed(address indexed bountyContract, address indexed creator)',
];

const NFT_REGISTRY_ABI = [
  'function walletToTokenId(address) view returns (uint256)',
  'function isVerified(uint256 tokenId) view returns (bool)',
  'function getReputationScore(uint256 tokenId) view returns (uint256)',
  'function getMemberships(uint256 tokenId) view returns (address[])',
  'function handles(uint256 tokenId) view returns (string)',
  'event NFTMinted(address indexed user, uint256 indexed tokenId, string handle)',
];

const PROJECT_ABI = [
  'function getState() view returns (uint8)',
  'function getMilestones() view returns (tuple[])',
  'function getEscrowBalance() view returns (uint256)',
  'function getAwardedContractor() view returns (address)',
  'function castProposalVote(bool upvote)',
  'function fundEscrow(uint256 amount, address token)',
  'function submitMilestoneCompletion(uint8 milestoneIndex, string ipfsEvidence)',
  'function signMilestone(uint8 milestoneIndex)',
  'function raiseDispute(string reason)',
  'function executeMediationRuling(tuple ruling)',
  'event StateTransition(uint8 from, uint8 to)',
  'event MilestonePaid(uint8 indexed milestoneIndex, address indexed contractor, uint256 amount)',
  'event ProjectCompleted(address indexed contractor, uint256 totalPaid)',
  'event DisputeRaised(address indexed raisedBy, string reason)',
];

/**
 * BlockchainService
 *
 * Central service for all EVM blockchain interactions.
 * All contract calls go through here — controllers never touch ethers.js directly.
 *
 * BUILD GUIDE:
 * ─────────────────────────────────────────────────────────────
 * This service has two main roles:
 *
 * 1. WRITE operations — called by controllers to trigger contract state changes.
 *    Uses the platform wallet (PLATFORM_PRIVATE_KEY) as a relay for Standard Mode users.
 *    For Crypto-Native users, the frontend signs transactions — the backend only validates.
 *
 * 2. READ operations — reading contract state for API responses.
 *    Uses a read-only provider (no private key needed).
 *
 * ABI management:
 *    After `forge build`, ABIs are in contracts/out/<ContractName>.sol/<ContractName>.json
 *    Replace the ABI fragments above with imports from those files:
 *    import FactoryABI from '../../../contracts/out/PlatformFactory.sol/PlatformFactory.json'
 *    const FACTORY_ABI = FactoryABI.abi;
 *
 * Gas:
 *    The platform wallet pays gas for Standard Mode users (NFT mint, community deploy).
 *    Consider a gas budget tracker — alert if platform wallet balance drops below threshold.
 * ─────────────────────────────────────────────────────────────
 */
export class BlockchainService {
  private static provider: ethers.JsonRpcProvider;
  private static platformWallet: ethers.Wallet;
  private static factory: ethers.Contract;
  private static nftRegistry: ethers.Contract;

  static init() {
    this.provider = new ethers.JsonRpcProvider(env.PRIMARY_RPC_URL);
    this.platformWallet = new ethers.Wallet(env.PLATFORM_PRIVATE_KEY, this.provider);
    this.factory = new ethers.Contract(
      env.PLATFORM_FACTORY_ADDRESS!,
      FACTORY_ABI,
      this.platformWallet,
    );
    this.nftRegistry = new ethers.Contract(
      env.PLATFORM_NFT_REGISTRY_ADDRESS!,
      NFT_REGISTRY_ABI,
      this.provider,
    );
    logger.info('BlockchainService initialized', { chainId: env.PRIMARY_CHAIN_ID });
  }

  // ── NFT operations ──────────────────────────────────────────

  /**
   * Mint a platform NFT for a new user.
   * Called by AuthController.register() after creating the user in the DB.
   *
   * TODO: Add retry logic with exponential backoff for failed transactions.
   * TODO: Store the txHash in the DB and update tokenId once confirmed.
   */
  static async mintPlatformNFT(walletAddress: string, handle: string): Promise<{ tokenId: number; txHash: string }> {
    logger.info(`Minting NFT for ${walletAddress} (handle: ${handle})`);
    const tx = await this.factory.mintPlatformNFT(walletAddress, handle);
    const receipt = await tx.wait();
    // TODO: Parse NFTMinted event from receipt to get tokenId
    const tokenId = 0; // Replace with event parsing
    return { tokenId, txHash: receipt.hash };
  }

  static async getNFTData(walletAddress: string) {
    const tokenId = await this.nftRegistry.walletToTokenId(walletAddress);
    if (tokenId === 0n) return null;
    const [handle, isVerified, reputationScore, memberships] = await Promise.all([
      this.nftRegistry.handles(tokenId),
      this.nftRegistry.isVerified(tokenId),
      this.nftRegistry.getReputationScore(tokenId),
      this.nftRegistry.getMemberships(tokenId),
    ]);
    return { tokenId: Number(tokenId), handle, isVerified, reputationScore: Number(reputationScore), memberships };
  }

  // ── Community operations ────────────────────────────────────

  /**
   * Deploy a CommunityRegistry contract via the factory.
   *
   * TODO: Implement. Pass council config + governance params.
   * Listen for CommunityDeployed event to get the contract address.
   * Save the deployed address to the DB.
   */
  static async deployCommunity(params: {
    name: string;
    councilSigners: string[];
    councilThreshold: number;
    governanceParams: Record<string, unknown>;
  }): Promise<{ contractAddress: string; txHash: string }> {
    // TODO: Implement
    throw new Error('deployCommunity not yet implemented — see BlockchainService.ts BUILD GUIDE');
  }

  // ── Project operations ──────────────────────────────────────

  /**
   * Get a ProjectContract instance for a given address.
   * Used by ProjectService to read state and submit transactions.
   */
  static getProjectContract(address: string, signer?: ethers.Signer): ethers.Contract {
    return new ethers.Contract(address, PROJECT_ABI, signer ?? this.provider);
  }

  /**
   * Fund escrow for a project on behalf of a Standard Mode user.
   * Crypto-Native users fund directly from the frontend — this is not called for them.
   *
   * TODO: Implement. Approve escrow token spend, then call fundEscrow().
   * The funder's stablecoin comes from the on-ramp webhook (see EscrowService).
   */
  static async fundProjectEscrow(params: {
    projectContractAddress: string;
    amount: bigint;
    tokenAddress: string;
    funderPrivateKey: string;
  }): Promise<string> {
    // TODO: Implement
    throw new Error('fundProjectEscrow not yet implemented');
  }

  // ── Utility ──────────────────────────────────────────────────

  static async getChainId(): Promise<number> {
    const network = await this.provider.getNetwork();
    return Number(network.chainId);
  }

  static async getPlatformWalletBalance(): Promise<bigint> {
    return this.provider.getBalance(env.PLATFORM_WALLET_ADDRESS);
  }
}
