// Mirror of backend/src/types/index.ts — keep in sync

export enum ProjectState {
  PROPOSED = 'PROPOSED', COUNCIL_REVIEW = 'COUNCIL_REVIEW', TENDERING = 'TENDERING',
  AWARDED = 'AWARDED', ACTIVE = 'ACTIVE', MILESTONE_UNDER_REVIEW = 'MILESTONE_UNDER_REVIEW',
  MILESTONE_PAID = 'MILESTONE_PAID', COMPLETION_VOTE = 'COMPLETION_VOTE',
  COMPLETED = 'COMPLETED', DISPUTED = 'DISPUTED', EXPIRED = 'EXPIRED', CLOSED = 'CLOSED',
}

export enum MilestoneVerificationType {
  COUNCIL_ONLY = 'COUNCIL_ONLY',
  COUNCIL_MEMBER_QUORUM = 'COUNCIL_MEMBER_QUORUM',
  FULL_COMMUNITY_VOTE = 'FULL_COMMUNITY_VOTE',
}

export enum MilestoneState {
  PENDING = 'PENDING', UNDER_REVIEW = 'UNDER_REVIEW', PAID = 'PAID', REJECTED = 'REJECTED',
}

export enum VisibilityMode {
  COMMUNITY_INTERNAL = 'COMMUNITY_INTERNAL', PLATFORM_PUBLIC = 'PLATFORM_PUBLIC',
  COMMUNITY_TARGETED = 'COMMUNITY_TARGETED', DUAL_PUBLICITY = 'DUAL_PUBLICITY',
  MULTI_COMMUNITY_TARGETED = 'MULTI_COMMUNITY_TARGETED',
}

export enum MemberRole { MEMBER = 'MEMBER', COUNCIL = 'COUNCIL' }
export enum VoteChoice { COMPLETED = 'COMPLETED', PARTIAL = 'PARTIAL', NOT_SATISFACTORY = 'NOT_SATISFACTORY', DISPUTE = 'DISPUTE' }
export enum UserMode { STANDARD = 'STANDARD', CRYPTO_NATIVE = 'CRYPTO_NATIVE' }

export interface Milestone {
  index: number;
  name: string;
  description: string;
  valueUsdc: bigint;
  expectedCompletionDate: string;
  verificationType: MilestoneVerificationType;
  state: MilestoneState;
  ipfsEvidence?: string;
  signaturesReceived: number;
  signaturesRequired: number;
}

export interface Project {
  id: string;
  contractAddress?: string;
  communityId: string;
  state: ProjectState;
  ipfsProposalHash: string;
  proposerAddress: string;
  awardedContractor?: string;
  totalEscrowUsdc: bigint;
  milestones: Milestone[];
  visibility: VisibilityMode;
  upvoteCount: number;
  downvoteCount: number;
  createdAt: string;
}

export interface Community {
  id: string;
  contractAddress?: string;
  name: string;
  type: string;
  description: string;
  memberCount: number;
  projectCount: number;
  completedProjectCount: number;
}

export interface Bounty {
  id: string;
  contractAddress?: string;
  creatorId: string;
  state: ProjectState;
  ipfsBountyHash: string;
  totalEscrowUsdc: bigint;
  milestones: Milestone[];
  visibility: VisibilityMode;
  createdAt: string;
}

export interface Bid {
  id: string;
  contractorAddress: string;
  contractorHandle: string;
  totalCostUsdc: bigint;
  proposedTimelineDays: number;
  methodology: string;
  ipfsBidDocument?: string;
  submittedAt: string;
  reputation?: { completionRate: number; communityRating: number; isKycVerified: boolean };
}
