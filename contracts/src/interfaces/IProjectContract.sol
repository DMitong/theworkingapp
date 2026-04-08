// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./IDataTypes.sol";

/// @title IProjectContract
/// @notice Interface for a community project child contract.
///         Each project deployed by a CommunityRegistry gets its own contract.
interface IProjectContract is IDataTypes {
    // ─── Events ──────────────────────────────────────────────────────────────

    event ProposalSubmitted(address indexed proposer, string ipfsHash);
    event ProposalVoteCast(address indexed voter, bool upvote, uint256 upvotes, uint256 downvotes);
    event CouncilReviewTriggered(uint256 upvotes, uint256 totalVotes);
    event CouncilDecision(AwardDecision decision, string reason);
    event TenderPublished(VisibilityMode visibility, address[] targetCommunities);
    event BidSubmitted(address indexed contractor, uint256 totalCost, string ipfsBidHash);
    event ContractAwarded(address indexed contractor, uint256 totalValue);
    event AwardAccepted(address indexed contractor);
    event EscrowFunded(address indexed funder, uint256 amount, address token);
    event PortionGrantRequested(address indexed contractor, uint256 amount);
    event PortionGrantApproved(uint256 amount);
    event MilestoneClaimSubmitted(uint8 indexed milestoneIndex, string ipfsEvidence);
    event MilestoneSigned(uint8 indexed milestoneIndex, address indexed signer, uint8 sigCount);
    event MilestoneVoteCast(uint8 indexed milestoneIndex, address indexed voter, uint8 choice);
    event MilestonePaid(uint8 indexed milestoneIndex, address indexed contractor, uint256 amount);
    event MilestoneRejected(uint8 indexed milestoneIndex, uint8 rejectionCount);
    event CompletionVoteOpened();
    event CompletionVoteCast(address indexed voter, VoteChoice choice);
    event ProjectCompleted(address indexed contractor, uint256 totalPaid);
    event DisputeRaised(address indexed raisedBy, string reason);
    event MediationRulingExecuted(MediationRuling ruling);
    event StateTransition(ProjectState from, ProjectState to);

    // ─── Lifecycle functions ──────────────────────────────────────────────────

    /// @notice Community member or council submits proposal. State: → PROPOSED
    function submitProposal(string calldata ipfsProposalHash) external;

    /// @notice Community member casts vote on proposal.
    function castProposalVote(bool upvote) external;

    /// @notice Council submits decision on a COUNCIL_REVIEW proposal.
    function councilDecision(AwardDecision decision, string calldata reason, bytes[] calldata signatures) external;

    /// @notice Council publishes approved project as tender. State: TENDERING
    function publishTender(VisibilityMode visibility, address[] calldata targetCommunities, bytes[] calldata signatures) external;

    /// @notice Contractor submits a bid during the bidding window.
    function submitBid(BidData calldata bid) external;

    /// @notice Council (or vote outcome) awards contract to a contractor.
    function awardContract(address contractor, MilestoneDefinition[] calldata milestones, bytes[] calldata signatures) external;

    /// @notice Awarded contractor accepts the milestone schedule.
    function acceptAward() external;

    /// @notice Funder deposits escrow (USDT or USDC). Must match sum of milestone values.
    function fundEscrow(uint256 amount, address token) external;

    // ─── Portion grant ────────────────────────────────────────────────────────

    /// @notice Contractor requests a mobilisation advance. Max 30% of total.
    function requestPortionGrant(uint256 amount, string calldata ipfsPurpose) external;

    /// @notice Council/community approves the portion grant.
    function approvePortionGrant(bytes[] calldata signatures) external;

    // ─── Milestone execution ──────────────────────────────────────────────────

    /// @notice Contractor claims completion of a milestone with evidence.
    function submitMilestoneCompletion(uint8 milestoneIndex, string calldata ipfsEvidence) external;

    /// @notice Council member signs a milestone (for COUNCIL_ONLY and COUNCIL_MEMBER_QUORUM types).
    function signMilestone(uint8 milestoneIndex) external;

    /// @notice Community member casts vote on a milestone (for COUNCIL_MEMBER_QUORUM and FULL_COMMUNITY_VOTE types).
    function castMilestoneVote(uint8 milestoneIndex, uint8 choice) external;

    // ─── Completion & dispute ─────────────────────────────────────────────────

    /// @notice Community member casts final completion vote.
    function castCompletionVote(VoteChoice choice) external;

    /// @notice Either party raises a dispute. Freezes remaining escrow.
    function raiseDispute(string calldata reason) external;

    /// @notice Platform mediation key executes a binding ruling.
    function executeMediationRuling(MediationRuling calldata ruling) external;

    // ─── Views ────────────────────────────────────────────────────────────────

    function getState() external view returns (ProjectState);
    function getMilestones() external view returns (MilestoneDefinition[] memory);
    function getBids() external view returns (BidData[] memory, address[] memory bidders);
    function getEscrowBalance() external view returns (uint256);
    function getAwardedContractor() external view returns (address);
}
