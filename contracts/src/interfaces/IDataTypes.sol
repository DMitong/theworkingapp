// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IDataTypes
/// @notice Central file for all shared structs and enums used across The Working App contracts.
///         Import this file in every contract that needs these types.
interface IDataTypes {
    // ─── Enums ───────────────────────────────────────────────────────────────

    enum ProjectState {
        PROPOSED,
        COUNCIL_REVIEW,
        TENDERING,
        AWARDED,
        ACTIVE,
        MILESTONE_UNDER_REVIEW,
        MILESTONE_PAID,
        COMPLETION_VOTE,
        COMPLETED,
        DISPUTED,
        EXPIRED,
        CLOSED
    }

    enum MilestoneVerificationType {
        COUNCIL_ONLY,        // Council multisig sign-off
        COUNCIL_MEMBER_QUORUM, // Council sign-off + member quorum
        FULL_COMMUNITY_VOTE  // Open vote to all community members
    }

    enum MilestoneState {
        PENDING,
        UNDER_REVIEW,
        PAID,
        REJECTED
    }

    enum VoteOutcome {
        PENDING,
        APPROVED,
        REJECTED,
        DISPUTED
    }

    enum VoteChoice {
        COMPLETED,        // Completed as specified
        PARTIAL,          // Partially completed
        NOT_SATISFACTORY, // Not satisfactory
        DISPUTE           // Raise dispute
    }

    enum VisibilityMode {
        COMMUNITY_INTERNAL,
        PLATFORM_PUBLIC,
        COMMUNITY_TARGETED,
        DUAL_PUBLICITY,
        MULTI_COMMUNITY_TARGETED
    }

    enum MemberRole {
        MEMBER,
        COUNCIL
    }

    enum MembershipVerificationMode {
        OPEN,
        INVITE_CODE,
        ADDRESS_PROOF,
        DOMAIN_EMAIL,
        ZK_KYC_REQUIRED,
        DOCUMENT_REVIEW,
        NFT_GATED,
        CUSTOM
    }

    enum AwardDecision {
        APPROVE,
        REQUEST_REVISION,
        CLOSE
    }

    // ─── Structs ─────────────────────────────────────────────────────────────

    struct MilestoneDefinition {
        string name;
        string description;
        uint256 value;               // In escrow token units (USDT/USDC 6 decimals)
        uint256 expectedCompletionTs; // Unix timestamp
        MilestoneVerificationType verificationType;
        MilestoneState state;
        string ipfsEvidence;         // Set when contractor submits claim
        uint8 signaturesReceived;
        uint8 signaturesRequired;
        uint8 rejectionCount;
    }

    struct CouncilConfig {
        address[] signers;
        uint8 threshold;             // Min signatures required for council actions
    }

    struct GovernanceParams {
        uint256 proposalApprovalThreshold; // Basis points (e.g., 6000 = 60%)
        uint256 proposalVotingWindow;      // Seconds
        uint256 completionVoteWindow;      // Seconds
        uint256 bidWindow;                 // Seconds
        uint256 councilReviewWindow;       // Seconds — before escalation flag
        uint256 tier1Threshold;            // Below = council awards directly (USDT units)
        uint256 tier2Threshold;            // Above = full community vote
        uint256 minMembers;                // Minimum active members (default 2)
        uint8 portionGrantMaxPercent;      // Default 30 (%)
        MembershipVerificationMode verificationMode;
    }

    struct ReputationUpdate {
        bool projectCompleted;
        bool projectDisputed;
        bool projectAwarded;
        uint8 completionVoteScore;   // 0–100, derived from vote outcome
    }

    struct BidData {
        uint256 totalCost;
        string ipfsBidDocument;      // IPFS hash of full bid package
        uint256 proposedTimeline;    // Seconds to project completion
        string methodology;
    }

    struct MediationRuling {
        address contractor;
        address funder;
        uint256 contractorAmount;    // USDT/USDC units
        uint256 funderRefund;        // USDT/USDC units
        string rulingIpfsHash;       // Evidence and rationale document
    }
}
