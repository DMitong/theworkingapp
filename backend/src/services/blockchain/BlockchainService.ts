import { ethers } from 'ethers';
import { env } from '../../config/env';
import { logger } from '../../utils/logger';
import { AppError } from '../../utils/AppError';

// Full ABIs from Foundry build output
import PlatformFactoryABI from '../../abis/PlatformFactory.json';
import PlatformNFTRegistryABI from '../../abis/PlatformNFTRegistry.json';
import CommunityRegistryABI from '../../abis/CommunityRegistry.json';
import ProjectContractABI from '../../abis/ProjectContract.json';
import BountyContractABI from '../../abis/BountyContract.json';

/**
 * BlockchainService
 *
 * Central service for all EVM blockchain interactions.
 * All contract calls go through here — controllers never touch ethers.js directly.
 *
 * WRITE operations use the platform wallet (PLATFORM_PRIVATE_KEY) as a relay for Standard Mode users.
 * READ operations use a read-only provider (no private key needed).
 */
export class BlockchainService {
  private static provider: ethers.JsonRpcProvider;
  private static platformWallet: ethers.Wallet;
  private static factory: ethers.Contract;
  private static nftRegistry: ethers.Contract;

  /**
   * Initialize provider, wallet, and core contract instances.
   * Call from src/index.ts on server startup.
   */
  static init() {
    this.provider = new ethers.JsonRpcProvider(env.PRIMARY_RPC_URL);
    this.platformWallet = new ethers.Wallet(env.PLATFORM_PRIVATE_KEY, this.provider);

    if (env.PLATFORM_FACTORY_ADDRESS) {
      this.factory = new ethers.Contract(
        env.PLATFORM_FACTORY_ADDRESS,
        PlatformFactoryABI.abi,
        this.platformWallet,
      );
    }

    if (env.PLATFORM_NFT_REGISTRY_ADDRESS) {
      this.nftRegistry = new ethers.Contract(
        env.PLATFORM_NFT_REGISTRY_ADDRESS,
        PlatformNFTRegistryABI.abi,
        this.provider,
      );
    }

    logger.info('BlockchainService initialized', {
      chainId: env.PRIMARY_CHAIN_ID,
      wallet: env.PLATFORM_WALLET_ADDRESS,
    });
  }

  // ── NFT operations ──────────────────────────────────────────────

  /**
   * Mint a platform NFT for a new user.
   * Called by AuthService.register() after creating the user in the DB.
   * Parses the NFTMinted event to extract the tokenId.
   */
  static async mintPlatformNFT(
    walletAddress: string,
    handle: string,
  ): Promise<{ tokenId: number; txHash: string }> {
    logger.info(`Minting NFT for ${walletAddress} (handle: ${handle})`);

    try {
      const tx = await this.factory.mintPlatformNFT(walletAddress, handle);
      const receipt = await tx.wait();

      // Parse NFTMinted event from receipt
      const nftRegistryInterface = new ethers.Interface(PlatformNFTRegistryABI.abi);
      let tokenId = 0;

      for (const log of receipt.logs) {
        try {
          const parsed = nftRegistryInterface.parseLog({ topics: log.topics as string[], data: log.data });
          if (parsed && parsed.name === 'NFTMinted') {
            tokenId = Number(parsed.args.tokenId);
            break;
          }
        } catch {
          // Not an NFTMinted event, skip
        }
      }

      logger.info(`NFT minted: tokenId=${tokenId}, tx=${receipt.hash}`);
      return { tokenId, txHash: receipt.hash };
    } catch (error) {
      logger.error('Failed to mint NFT', { walletAddress, handle, error });
      throw new AppError('Failed to mint platform NFT', 502);
    }
  }

  /**
   * Read all on-chain identity data for a wallet address.
   * Returns null if the wallet has no NFT.
   */
  static async getNFTData(walletAddress: string) {
    const tokenId = await this.nftRegistry.walletToTokenId(walletAddress);
    if (tokenId === 0n) return null;

    const [handle, isVerified, reputationScore, memberships] = await Promise.all([
      this.nftRegistry.handles(tokenId),
      this.nftRegistry.isVerified(tokenId),
      this.nftRegistry.getReputationScore(tokenId),
      this.nftRegistry.getMemberships(tokenId),
    ]);

    return {
      tokenId: Number(tokenId),
      handle,
      isVerified,
      reputationScore: Number(reputationScore),
      memberships: memberships as string[],
    };
  }

  /**
   * Read detailed NFT counters for profile display.
   */
  static async getNFTProfileData(tokenId: number) {
    const [
      reputationScore,
      projectsCompleted,
      projectsAwarded,
      disputeCount,
      memberships,
      isVerified,
    ] = await Promise.all([
      this.nftRegistry.reputationScores(tokenId),
      this.nftRegistry.projectsCompleted(tokenId),
      this.nftRegistry.projectsAwarded(tokenId),
      this.nftRegistry.disputeCount(tokenId),
      this.nftRegistry.getMemberships(tokenId),
      this.nftRegistry.isVerified(tokenId),
    ]);

    return {
      tokenId,
      reputationScore: Number(reputationScore),
      projectsCompleted: Number(projectsCompleted),
      projectsAwarded: Number(projectsAwarded),
      disputeCount: Number(disputeCount),
      communityCount: (memberships as string[]).length,
      isVerified,
    };
  }

  // ── Community operations ────────────────────────────────────────

  /**
   * Deploy a CommunityRegistry contract via PlatformFactory.
   * Parses the CommunityDeployed event to extract the contract address.
   */
  static async deployCommunity(params: {
    name: string;
    councilSigners: string[];
    councilThreshold: number;
    governanceParams: {
      proposalApprovalThreshold: number;
      proposalVotingWindow: number;
      completionVoteWindow: number;
      bidWindow: number;
      councilReviewWindow: number;
      tier1Threshold: bigint;
      tier2Threshold: bigint;
      minMembers: number;
      portionGrantMaxPercent: number;
      verificationMode: number;
    };
  }): Promise<{ contractAddress: string; txHash: string }> {
    logger.info(`Deploying community: ${params.name}`);

    try {
      const councilConfig = {
        signers: params.councilSigners,
        threshold: params.councilThreshold,
      };

      const govParams = {
        proposalApprovalThreshold: params.governanceParams.proposalApprovalThreshold,
        proposalVotingWindow: params.governanceParams.proposalVotingWindow,
        completionVoteWindow: params.governanceParams.completionVoteWindow,
        bidWindow: params.governanceParams.bidWindow,
        councilReviewWindow: params.governanceParams.councilReviewWindow,
        tier1Threshold: params.governanceParams.tier1Threshold,
        tier2Threshold: params.governanceParams.tier2Threshold,
        minMembers: params.governanceParams.minMembers,
        portionGrantMaxPercent: params.governanceParams.portionGrantMaxPercent,
        verificationMode: params.governanceParams.verificationMode,
      };

      const tx = await this.factory.deployCommunity(params.name, councilConfig, govParams);
      const receipt = await tx.wait();

      // Parse CommunityDeployed event
      const factoryInterface = new ethers.Interface(PlatformFactoryABI.abi);
      let contractAddress = '';

      for (const log of receipt.logs) {
        try {
          const parsed = factoryInterface.parseLog({ topics: log.topics as string[], data: log.data });
          if (parsed && parsed.name === 'CommunityDeployed') {
            contractAddress = parsed.args.communityRegistry;
            break;
          }
        } catch {
          // Not the event we want, skip
        }
      }

      if (!contractAddress) {
        throw new Error('CommunityDeployed event not found in receipt');
      }

      logger.info(`Community deployed at ${contractAddress}, tx=${receipt.hash}`);
      return { contractAddress, txHash: receipt.hash };
    } catch (error) {
      logger.error('Failed to deploy community', { name: params.name, error });
      throw new AppError('Failed to deploy community on-chain', 502);
    }
  }

  // ── Project operations ──────────────────────────────────────────

  /**
   * Get a ProjectContract instance for a given address.
   * Used by ProjectService to read state and submit transactions.
   */
  static getProjectContract(address: string, signer?: ethers.Signer): ethers.Contract {
    return new ethers.Contract(address, ProjectContractABI.abi, signer ?? this.provider);
  }

  /**
   * Get a CommunityRegistry instance for a given address.
   */
  static getCommunityContract(address: string, signer?: ethers.Signer): ethers.Contract {
    return new ethers.Contract(address, CommunityRegistryABI.abi, signer ?? this.platformWallet);
  }

  /**
   * Get a BountyContract instance for a given address.
   */
  static getBountyContract(address: string, signer?: ethers.Signer): ethers.Contract {
    return new ethers.Contract(address, BountyContractABI.abi, signer ?? this.provider);
  }

  /**
   * Read the on-chain state of a ProjectContract.
   */
  static async getProjectState(contractAddress: string): Promise<number> {
    const contract = this.getProjectContract(contractAddress);
    return Number(await contract.getState());
  }

  /**
   * Read the escrow balance of a project.
   */
  static async getProjectEscrowBalance(contractAddress: string): Promise<bigint> {
    const contract = this.getProjectContract(contractAddress);
    return contract.getEscrowBalance();
  }

  /**
   * Cast a proposal vote on behalf of a Standard Mode user.
   * The platform wallet relays the transaction.
   */
  static async castProposalVote(
    projectContractAddress: string,
    upvote: boolean,
  ): Promise<string> {
    const contract = this.getProjectContract(projectContractAddress, this.platformWallet);
    const tx = await contract.castProposalVote(upvote);
    const receipt = await tx.wait();
    return receipt.hash;
  }

  /**
   * Submit a milestone completion claim on-chain.
   */
  static async submitMilestoneCompletion(
    projectContractAddress: string,
    milestoneIndex: number,
    ipfsEvidence: string,
  ): Promise<string> {
    const contract = this.getProjectContract(projectContractAddress, this.platformWallet);
    const tx = await contract.submitMilestoneCompletion(milestoneIndex, ipfsEvidence);
    const receipt = await tx.wait();
    return receipt.hash;
  }

  /**
   * Sign a milestone as a council member.
   */
  static async signMilestone(
    projectContractAddress: string,
    milestoneIndex: number,
  ): Promise<string> {
    const contract = this.getProjectContract(projectContractAddress, this.platformWallet);
    const tx = await contract.signMilestone(milestoneIndex);
    const receipt = await tx.wait();
    return receipt.hash;
  }

  /**
   * Fund escrow for a project.
   * Approves the ERC20 spend, then calls fundEscrow on the contract.
   */
  static async fundProjectEscrow(params: {
    projectContractAddress: string;
    amount: bigint;
    tokenAddress: string;
    funderPrivateKey: string;
  }): Promise<string> {
    logger.info(`Funding escrow for ${params.projectContractAddress}, amount=${params.amount}`);

    const funderWallet = new ethers.Wallet(params.funderPrivateKey, this.provider);

    // 1. Approve the project contract to spend funder's tokens
    const erc20 = new ethers.Contract(
      params.tokenAddress,
      ['function approve(address spender, uint256 amount) returns (bool)'],
      funderWallet,
    );
    const approveTx = await erc20.approve(params.projectContractAddress, params.amount);
    await approveTx.wait();

    // 2. Call fundEscrow on the project contract
    const contract = this.getProjectContract(params.projectContractAddress, funderWallet);
    const fundTx = await contract.fundEscrow(params.amount, params.tokenAddress);
    const receipt = await fundTx.wait();

    logger.info(`Escrow funded, tx=${receipt.hash}`);
    return receipt.hash;
  }

  /**
   * Raise a dispute on a project.
   */
  static async raiseDispute(
    projectContractAddress: string,
    reason: string,
  ): Promise<string> {
    const contract = this.getProjectContract(projectContractAddress, this.platformWallet);
    const tx = await contract.raiseDispute(reason);
    const receipt = await tx.wait();
    return receipt.hash;
  }

  // ── Utility ──────────────────────────────────────────────────────

  static getProvider(): ethers.JsonRpcProvider {
    return this.provider;
  }

  static getPlatformWallet(): ethers.Wallet {
    return this.platformWallet;
  }

  static async getChainId(): Promise<number> {
    const network = await this.provider.getNetwork();
    return Number(network.chainId);
  }

  static async getPlatformWalletBalance(): Promise<bigint> {
    return this.provider.getBalance(env.PLATFORM_WALLET_ADDRESS);
  }
}
