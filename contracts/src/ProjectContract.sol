// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/IProjectContract.sol";
import "./interfaces/IPlatformNFTRegistry.sol";

/// @title ProjectContract
/// @notice Child contract representing a single community project.
///         Manages the full lifecycle from proposal through milestone-gated
///         escrow release to final completion vote.
/// @dev    Deployed by CommunityRegistry.deployProject().
///         See contracts/BUILD.md — Step 6 for full implementation notes.
///
///         STATE MACHINE:
///         PROPOSED → COUNCIL_REVIEW → TENDERING → AWARDED → ACTIVE
///         → MILESTONE_UNDER_REVIEW ↔ MILESTONE_PAID (loops per milestone)
///         → COMPLETION_VOTE → COMPLETED | DISPUTED → (mediation) → COMPLETED | refunded
contract ProjectContract is IProjectContract, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ─── State ────────────────────────────────────────────────────────────────

    address public immutable communityRegistry;
    address public immutable platformFactory;
    address public mediationKey;          // Copied from factory at deploy time

    ProjectState public state;
    string public ipfsProposalHash;       // IPFS hash of proposal data
    address public escrowToken;           // USDT or USDC contract address
    VisibilityMode public visibility;
    address[] public targetCommunities;

    // Proposal voting
    mapping(address => int8) public proposalVotes; // 1 = up, -1 = down, 0 = not voted
    uint256 public upvoteCount;
    uint256 public downvoteCount;
    uint256 public proposalVoteDeadline;

    // Contracting
    address[] public bidderList;
    mapping(address => BidData) public bids;
    address public awardedContractor;
    uint256 public totalEscrowRequired;

    // Milestones
    MilestoneDefinition[] public milestones;
    uint8 public currentMilestoneIndex;
    mapping(uint8 => mapping(address => bool)) public milestoneSignatures;
    mapping(uint8 => mapping(address => uint8)) public milestoneVotes;
    mapping(uint8 => uint256) public milestoneVoteCount;

    // Portion grant
    uint256 public portionGrantAmount;
    bool public portionGrantRequested;
    bool public portionGrantApproved;

    // Completion vote
    mapping(address => VoteChoice) public completionVotes;
    mapping(VoteChoice => uint256) public completionVoteCounts;
    uint256 public completionVoteDeadline;
    bool public completionVoteCast;

    // Dispute
    bool public disputeActive;
    string public disputeReason;
    address public disputeRaisedBy;

    // Governance snapshot (copied from CommunityRegistry at deploy time)
    GovernanceParams public governanceParams;
    address[] public councilSigners;
    uint8 public councilThreshold;

    IPlatformNFTRegistry public nftRegistry;

    // ─── Constructor ──────────────────────────────────────────────────────────

    constructor(
        address _communityRegistry,
        address _platformFactory,
        address _mediationKey,
        address _nftRegistry,
        string memory _ipfsProposalHash,
        address _escrowToken,
        VisibilityMode _visibility,
        address[] memory _targetCommunities,
        GovernanceParams memory _govParams,
        address[] memory _councilSigners,
        uint8 _councilThreshold
    ) {
        communityRegistry = _communityRegistry;
        platformFactory = _platformFactory;
        mediationKey = _mediationKey;
        nftRegistry = IPlatformNFTRegistry(_nftRegistry);
        ipfsProposalHash = _ipfsProposalHash;
        escrowToken = _escrowToken;
        visibility = _visibility;
        targetCommunities = _targetCommunities;
        governanceParams = _govParams;
        councilSigners = _councilSigners;
        councilThreshold = _councilThreshold;

        state = ProjectState.PROPOSED;
        proposalVoteDeadline = block.timestamp + _govParams.proposalVotingWindow;

        emit ProposalSubmitted(msg.sender, _ipfsProposalHash);
        emit StateTransition(ProjectState.PROPOSED, ProjectState.PROPOSED);
    }

    // ─── Modifiers ────────────────────────────────────────────────────────────

    modifier onlyState(ProjectState required) {
        require(state == required, "Invalid state for this action");
        _;
    }

    modifier onlyMember() {
        require(
            ICommunityRegistry_isMember(communityRegistry, msg.sender),
            "Only community members"
        );
        _;
    }

    modifier onlyContractor() {
        require(msg.sender == awardedContractor, "Only awarded contractor");
        _;
    }

    modifier onlyMediationKey() {
        require(msg.sender == mediationKey, "Only mediation key");
        _;
    }

    // ─── Proposal voting ──────────────────────────────────────────────────────

    function submitProposal(string calldata ipfsHash) external {
        // NOTE: In this implementation, the proposal is submitted at construction.
        // This function is available if the registry pattern requires a separate submission step.
        revert("Proposal submitted at construction");
    }

    function castProposalVote(bool upvote) external onlyMember onlyState(ProjectState.PROPOSED) {
        require(block.timestamp <= proposalVoteDeadline, "Voting window closed");
        require(proposalVotes[msg.sender] == 0, "Already voted");

        proposalVotes[msg.sender] = upvote ? int8(1) : int8(-1);
        if (upvote) upvoteCount++; else downvoteCount++;

        emit ProposalVoteCast(msg.sender, upvote, upvoteCount, downvoteCount);

        // Check if approval threshold reached
        // TODO: Get total member count from community registry for threshold calculation
        // For now, trigger on absolute upvote count matching governance threshold logic
        _checkProposalThreshold();
    }

    function _checkProposalThreshold() internal {
        // TODO: Implement threshold check against governanceParams.proposalApprovalThreshold
        // threshold is in basis points relative to total eligible voters
        // If met: transition to COUNCIL_REVIEW
        // emit CouncilReviewTriggered(upvoteCount, upvoteCount + downvoteCount);
        // _transition(ProjectState.COUNCIL_REVIEW);
    }

    // ─── Council decision ─────────────────────────────────────────────────────

    /// @dev TODO: Implement with council multisig verification.
    function councilDecision(AwardDecision decision, string calldata reason, bytes[] calldata signatures)
        external onlyState(ProjectState.COUNCIL_REVIEW)
    {
        // TODO: _verifyCouncilSignatures(...)
        // if APPROVE: _transition(TENDERING); publish tender
        // if REQUEST_REVISION: _transition(PROPOSED); reset vote window
        // if CLOSE: _transition(CLOSED); record reason on-chain
        revert("Not implemented - see BUILD.md Step 6");
    }

    /// @dev TODO: Implement tender publication with visibility settings.
    function publishTender(VisibilityMode _visibility, address[] calldata _targetCommunities, bytes[] calldata signatures)
        external onlyState(ProjectState.TENDERING)
    {
        revert("Not implemented - see BUILD.md Step 6");
    }

    // ─── Bidding ──────────────────────────────────────────────────────────────

    function submitBid(BidData calldata bid) external onlyState(ProjectState.TENDERING) {
        require(bids[msg.sender].totalCost == 0, "Already submitted bid");
        bids[msg.sender] = bid;
        bidderList.push(msg.sender);
        emit BidSubmitted(msg.sender, bid.totalCost, bid.ipfsBidDocument);
    }

    // ─── Award ────────────────────────────────────────────────────────────────

    /// @dev TODO: Implement tiered award logic. See BUILD.md Step 6.
    function awardContract(address contractor, MilestoneDefinition[] calldata _milestones, bytes[] calldata signatures)
        external onlyState(ProjectState.TENDERING)
    {
        // TODO: Check award tier vs governanceParams.tier1Threshold / tier2Threshold
        // TODO: Verify council signatures or vote outcome
        // TODO: Validate milestones sum to total bid value
        // TODO: Set milestones, awardedContractor, totalEscrowRequired
        // TODO: _transition(AWARDED)
        revert("Not implemented - see BUILD.md Step 6");
    }

    function acceptAward() external onlyState(ProjectState.AWARDED) onlyContractor {
        // State remains AWARDED until escrow is funded
        emit AwardAccepted(awardedContractor);
    }

    // ─── Escrow funding ───────────────────────────────────────────────────────

    function fundEscrow(uint256 amount, address token) external nonReentrant onlyState(ProjectState.AWARDED) {
        require(token == escrowToken, "Wrong token");
        require(amount == totalEscrowRequired, "Amount must match total project value");
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        _transition(ProjectState.ACTIVE);
        emit EscrowFunded(msg.sender, amount, token);
    }

    // ─── Portion grant ────────────────────────────────────────────────────────

    function requestPortionGrant(uint256 amount, string calldata ipfsPurpose)
        external onlyState(ProjectState.ACTIVE) onlyContractor
    {
        require(!portionGrantRequested, "Grant already requested");
        require(amount <= (totalEscrowRequired * governanceParams.portionGrantMaxPercent) / 100, "Exceeds max grant");
        portionGrantAmount = amount;
        portionGrantRequested = true;
        emit PortionGrantRequested(msg.sender, amount);
    }

    /// @dev TODO: Implement approval — council vote for sub-tier, community vote for above-tier.
    function approvePortionGrant(bytes[] calldata signatures)
        external onlyState(ProjectState.ACTIVE)
    {
        require(portionGrantRequested && !portionGrantApproved, "Invalid grant state");
        // TODO: verify signatures / vote outcome
        portionGrantApproved = true;
        IERC20(escrowToken).safeTransfer(awardedContractor, portionGrantAmount);
        emit PortionGrantApproved(portionGrantAmount);
    }

    // ─── Milestone execution ──────────────────────────────────────────────────

    function submitMilestoneCompletion(uint8 milestoneIndex, string calldata ipfsEvidence)
        external onlyState(ProjectState.ACTIVE) onlyContractor
    {
        require(milestoneIndex == currentMilestoneIndex, "Must complete milestones in order");
        require(milestones[milestoneIndex].state == MilestoneState.PENDING, "Milestone not pending");
        milestones[milestoneIndex].ipfsEvidence = ipfsEvidence;
        milestones[milestoneIndex].state = MilestoneState.UNDER_REVIEW;
        _transition(ProjectState.MILESTONE_UNDER_REVIEW);
        emit MilestoneClaimSubmitted(milestoneIndex, ipfsEvidence);
    }

    function signMilestone(uint8 milestoneIndex) external onlyState(ProjectState.MILESTONE_UNDER_REVIEW) {
        MilestoneDefinition storage milestone = milestones[milestoneIndex];
        require(
            milestone.verificationType == MilestoneVerificationType.COUNCIL_ONLY ||
            milestone.verificationType == MilestoneVerificationType.COUNCIL_MEMBER_QUORUM,
            "Milestone not council sign-off type"
        );
        require(!milestoneSignatures[milestoneIndex][msg.sender], "Already signed");
        require(_isCouncilMember(msg.sender), "Not a council member");

        milestoneSignatures[milestoneIndex][msg.sender] = true;
        milestone.signaturesReceived++;
        emit MilestoneSigned(milestoneIndex, msg.sender, milestone.signaturesReceived);

        if (milestone.signaturesReceived >= milestone.signaturesRequired) {
            _releaseMilestonePayment(milestoneIndex);
        }
    }

    function castMilestoneVote(uint8 milestoneIndex, uint8 choice)
        external onlyState(ProjectState.MILESTONE_UNDER_REVIEW) onlyMember
    {
        // TODO: Implement vote tracking and threshold check
        // On threshold met: _releaseMilestonePayment(milestoneIndex)
        revert("Not implemented - see BUILD.md Step 6");
    }

    // ─── Completion vote ──────────────────────────────────────────────────────

    function castCompletionVote(VoteChoice choice) external onlyState(ProjectState.COMPLETION_VOTE) onlyMember {
        require(block.timestamp <= completionVoteDeadline, "Vote window closed");
        require(!completionVoteCast, "Already voted");
        // TODO: Track per-member vote, update counts, check for outcome threshold
        // On COMPLETED outcome: _releaseAllEscrow()
        // On DISPUTED: _transition(DISPUTED)
        revert("Not implemented - see BUILD.md Step 6");
    }

    // ─── Dispute ─────────────────────────────────────────────────────────────

    function raiseDispute(string calldata reason) external {
        require(msg.sender == awardedContractor || ICommunityRegistry_isMember(communityRegistry, msg.sender), "Unauthorized");
        require(!disputeActive, "Dispute already active");
        disputeActive = true;
        disputeReason = reason;
        disputeRaisedBy = msg.sender;
        _transition(ProjectState.DISPUTED);
        emit DisputeRaised(msg.sender, reason);
    }

    function executeMediationRuling(MediationRuling calldata ruling) external onlyMediationKey nonReentrant {
        require(state == ProjectState.DISPUTED, "Not in dispute");
        uint256 contractBal = IERC20(escrowToken).balanceOf(address(this));
        require(ruling.contractorAmount + ruling.funderRefund <= contractBal, "Ruling exceeds balance");

        if (ruling.contractorAmount > 0) {
            IERC20(escrowToken).safeTransfer(ruling.contractor, ruling.contractorAmount);
        }
        if (ruling.funderRefund > 0) {
            IERC20(escrowToken).safeTransfer(ruling.funder, ruling.funderRefund);
        }
        _transition(ProjectState.COMPLETED);
        emit MediationRulingExecuted(ruling);
    }

    // ─── Internal helpers ─────────────────────────────────────────────────────

    function _releaseMilestonePayment(uint8 milestoneIndex) internal nonReentrant {
        MilestoneDefinition storage milestone = milestones[milestoneIndex];
        milestone.state = MilestoneState.PAID;
        uint256 payment = milestone.value;

        // Deduct portion grant from first milestone
        if (milestoneIndex == 0 && portionGrantApproved) {
            payment = payment > portionGrantAmount ? payment - portionGrantAmount : 0;
        }

        IERC20(escrowToken).safeTransfer(awardedContractor, payment);
        emit MilestonePaid(milestoneIndex, awardedContractor, payment);

        currentMilestoneIndex++;

        // Check if this was the last milestone
        if (currentMilestoneIndex >= milestones.length) {
            // Open final completion vote
            completionVoteDeadline = block.timestamp + governanceParams.completionVoteWindow;
            _transition(ProjectState.COMPLETION_VOTE);
            emit CompletionVoteOpened();
        } else {
            _transition(ProjectState.ACTIVE);
        }
    }

    function _transition(ProjectState newState) internal {
        ProjectState oldState = state;
        state = newState;
        emit StateTransition(oldState, newState);
    }

    function _isCouncilMember(address user) internal view returns (bool) {
        for (uint256 i = 0; i < councilSigners.length; i++) {
            if (councilSigners[i] == user) return true;
        }
        return false;
    }

    /// @dev Helper to call isMember on CommunityRegistry without importing it (avoids circular deps).
    function ICommunityRegistry_isMember(address registry, address user) internal view returns (bool) {
        (bool success, bytes memory data) = registry.staticcall(
            abi.encodeWithSignature("isMember(address)", user)
        );
        if (!success || data.length == 0) return false;
        return abi.decode(data, (bool));
    }

    // ─── Views ────────────────────────────────────────────────────────────────

    function getState() external view returns (ProjectState) { return state; }
    function getMilestones() external view returns (MilestoneDefinition[] memory) { return milestones; }
    function getBids() external view returns (BidData[] memory, address[] memory) {
        BidData[] memory bidData = new BidData[](bidderList.length);
        for (uint256 i = 0; i < bidderList.length; i++) {
            bidData[i] = bids[bidderList[i]];
        }
        return (bidData, bidderList);
    }
    function getEscrowBalance() external view returns (uint256) {
        return IERC20(escrowToken).balanceOf(address(this));
    }
    function getAwardedContractor() external view returns (address) { return awardedContractor; }
}
