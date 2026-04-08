// ── Enums (mirror Solidity enums) ────────────────────────────

export enum ProjectState {
  PROPOSED = 'PROPOSED',
  COUNCIL_REVIEW = 'COUNCIL_REVIEW',
  TENDERING = 'TENDERING',
  AWARDED = 'AWARDED',
  ACTIVE = 'ACTIVE',
  MILESTONE_UNDER_REVIEW = 'MILESTONE_UNDER_REVIEW',
  MILESTONE_PAID = 'MILESTONE_PAID',
  COMPLETION_VOTE = 'COMPLETION_VOTE',
  COMPLETED = 'COMPLETED',
  DISPUTED = 'DISPUTED',
  EXPIRED = 'EXPIRED',
  CLOSED = 'CLOSED',
}

export enum MilestoneVerificationType {
  COUNCIL_ONLY = 'COUNCIL_ONLY',
  COUNCIL_MEMBER_QUORUM = 'COUNCIL_MEMBER_QUORUM',
  FULL_COMMUNITY_VOTE = 'FULL_COMMUNITY_VOTE',
}

export enum MilestoneState {
  PENDING = 'PENDING',
  UNDER_REVIEW = 'UNDER_REVIEW',
  PAID = 'PAID',
  REJECTED = 'REJECTED',
}

export enum VisibilityMode {
  COMMUNITY_INTERNAL = 'COMMUNITY_INTERNAL',
  PLATFORM_PUBLIC = 'PLATFORM_PUBLIC',
  COMMUNITY_TARGETED = 'COMMUNITY_TARGETED',
  DUAL_PUBLICITY = 'DUAL_PUBLICITY',
  MULTI_COMMUNITY_TARGETED = 'MULTI_COMMUNITY_TARGETED',
}

export enum MembershipVerificationMode {
  OPEN = 'OPEN',
  INVITE_CODE = 'INVITE_CODE',
  ADDRESS_PROOF = 'ADDRESS_PROOF',
  DOMAIN_EMAIL = 'DOMAIN_EMAIL',
  ZK_KYC_REQUIRED = 'ZK_KYC_REQUIRED',
  DOCUMENT_REVIEW = 'DOCUMENT_REVIEW',
  NFT_GATED = 'NFT_GATED',
  CUSTOM = 'CUSTOM',
}

export enum MemberRole {
  MEMBER = 'MEMBER',
  COUNCIL = 'COUNCIL',
}

export enum CommunityType {
  RESIDENTIAL = 'RESIDENTIAL',
  CIVIC = 'CIVIC',
  PROFESSIONAL = 'PROFESSIONAL',
  ALUMNI = 'ALUMNI',
  RELIGIOUS = 'RELIGIOUS',
  SOCIAL = 'SOCIAL',
  INDUSTRY = 'INDUSTRY',
  OTHER = 'OTHER',
}

export enum VoteChoice {
  COMPLETED = 'COMPLETED',
  PARTIAL = 'PARTIAL',
  NOT_SATISFACTORY = 'NOT_SATISFACTORY',
  DISPUTE = 'DISPUTE',
}

export enum UserMode {
  STANDARD = 'STANDARD',
  CRYPTO_NATIVE = 'CRYPTO_NATIVE',
}

// ── Core domain types ─────────────────────────────────────────

export interface User {
  id: string;
  email: string;
  handle: string;
  mode: UserMode;
  walletAddress: string;          // Platform-managed embedded wallet (Standard) or external
  externalWallet?: string;        // Connected external wallet (Crypto-Native mode)
  tokenId?: number;               // Platform NFT token ID
  isKycVerified: boolean;
  createdAt: Date;
}

export interface Community {
  id: string;
  contractAddress: string;
  chainId: number;
  name: string;
  type: CommunityType;
  description: string;
  scope?: string;
  memberCount: number;
  projectCount: number;
  completedProjectCount: number;
  totalValueCompleted: bigint;
  governanceParams: GovernanceParams;
  councilConfig: CouncilConfig;
  createdAt: Date;
}

export interface GovernanceParams {
  proposalApprovalThresholdBps: number;   // e.g. 6000 = 60%
  proposalVotingWindowSecs: number;
  completionVoteWindowSecs: number;
  bidWindowSecs: number;
  councilReviewWindowSecs: number;
  tier1ThresholdUsdc: bigint;
  tier2ThresholdUsdc: bigint;
  minMembers: number;
  portionGrantMaxPct: number;
  verificationMode: MembershipVerificationMode;
}

export interface CouncilConfig {
  signers: string[];              // Wallet addresses
  threshold: number;
}

export interface Milestone {
  index: number;
  name: string;
  description: string;
  valueUsdc: bigint;
  expectedCompletionDate: Date;
  verificationType: MilestoneVerificationType;
  state: MilestoneState;
  ipfsEvidence?: string;
  signaturesReceived: number;
  signaturesRequired: number;
}

export interface Project {
  id: string;
  contractAddress: string;
  communityId: string;
  chainId: number;
  state: ProjectState;
  ipfsProposalHash: string;
  proposerAddress: string;
  awardedContractor?: string;
  escrowToken: string;
  totalEscrowUsdc: bigint;
  milestones: Milestone[];
  visibility: VisibilityMode;
  targetCommunityIds: string[];
  upvoteCount: number;
  downvoteCount: number;
  portionGrantRequested: boolean;
  portionGrantApproved: boolean;
  portionGrantAmount: bigint;
  createdAt: Date;
  updatedAt: Date;
}

export interface Bid {
  id: string;
  projectId: string;
  contractorAddress: string;
  totalCostUsdc: bigint;
  ipfsBidDocument: string;
  proposedTimelineDays: number;
  methodology: string;
  submittedAt: Date;
}

export interface Bounty {
  id: string;
  contractAddress: string;
  creatorId: string;
  chainId: number;
  state: ProjectState;
  ipfsBountyHash: string;
  escrowToken: string;
  totalEscrowUsdc: bigint;
  milestones: Milestone[];
  visibility: VisibilityMode;
  targetCommunityIds: string[];
  selectedContractor?: string;
  completionPanelAddresses: string[];
  createdAt: Date;
}

export interface ContractorReputation {
  tokenId: number;
  walletAddress: string;
  handle: string;
  completionRate: number;         // 0–100
  communityRating: number;        // 0–100
  disputeRate: number;            // 0–100
  projectsCompleted: number;
  projectsAwarded: number;
  votesParticipated: number;
  disputeCount: number;
  isKycVerified: boolean;
  communityMemberships: string[]; // community contract addresses
  specialisations: string[];
}

// ── API response wrappers ─────────────────────────────────────

export interface ApiResponse<T> {
  success: boolean;
  data?: T;
  error?: string;
  message?: string;
}

export interface PaginatedResponse<T> {
  items: T[];
  total: number;
  page: number;
  pageSize: number;
  hasMore: boolean;
}

// ── Request body types ────────────────────────────────────────

export interface RegisterRequest {
  email: string;
  password: string;
  handle: string;
}

export interface CreateCommunityRequest {
  name: string;
  type: CommunityType;
  description: string;
  scope?: string;
  chainId: number;
  councilSigners: string[];
  councilThreshold: number;
  governanceParams: Omit<GovernanceParams, 'verificationMode'>;
  verificationMode: MembershipVerificationMode;
}

export interface CreateProjectRequest {
  communityId: string;
  ipfsProposalHash: string;
  milestones: Omit<Milestone, 'index' | 'state' | 'signaturesReceived'>[];
  escrowToken: 'USDT' | 'USDC';
  visibility: VisibilityMode;
  targetCommunityIds?: string[];
}

export interface CreateBountyRequest {
  ipfsBountyHash: string;
  milestones: Omit<Milestone, 'index' | 'state' | 'signaturesReceived'>[];
  escrowToken: 'USDT' | 'USDC';
  visibility: VisibilityMode;
  targetCommunityIds?: string[];
  chainId: number;
  completionPanelSize?: number;   // 0 = creator only
}
