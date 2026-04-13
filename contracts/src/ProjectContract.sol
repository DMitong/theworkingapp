// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "./interfaces/IProjectContract.sol";
import "./interfaces/IPlatformNFTRegistry.sol";
import "./libraries/Escrow.sol";
import "./libraries/MilestoneManager.sol";
import "./libraries/Voting.sol";

contract ProjectContract is IProjectContract, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;
    using Escrow for Escrow.Ledger;
    using MilestoneManager for MilestoneDefinition[];
    using Voting for Voting.Tally;

    address public immutable communityRegistry;
    address public immutable platformFactory;
    address public mediationKey;

    ProjectState public state;
    string public ipfsProposalHash;
    address public escrowToken;
    VisibilityMode public visibility;
    address[] public targetCommunities;

    // Proposal voting
    mapping(address => uint8) public proposalVotes; // 1 = up, 2 = down
    Voting.Tally private proposalVoteTally;
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
    mapping(uint8 => Voting.Tally) private milestoneTallies;

    // Escrow
    Escrow.Ledger private escrowLedger;

    // Portion grant
    uint256 public portionGrantAmount;
    bool public portionGrantRequested;
    bool public portionGrantApproved;

    // Completion vote
    mapping(address => uint8) public completionVotes; // 1=APPROVED, 2=REJECTED, 3=DISPUTED
    Voting.Tally private completionVoteTally;
    uint256 public completionVoteDeadline;
    bool public completionVoteCast;

    // Dispute
    bool public disputeActive;
    string public disputeReason;
    address public disputeRaisedBy;

    GovernanceParams public governanceParams;
    address[] public councilSigners;
    uint8 public councilThreshold;
    uint256 public councilNonce;

    IPlatformNFTRegistry public nftRegistry;

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
    
    function submitProposal(string calldata) external pure {
        revert("Proposal submitted at construction");
    }

    function castProposalVote(bool upvote) external onlyMember onlyState(ProjectState.PROPOSED) {
        require(block.timestamp <= proposalVoteDeadline, "Voting window closed");
        uint8 choice = upvote ? 1 : 2;
        Voting.castVote(proposalVotes, proposalVoteTally, msg.sender, choice);

        uint256 upvotes = proposalVoteTally.counts[1];
        uint256 downvotes = proposalVoteTally.counts[2];

        emit ProposalVoteCast(msg.sender, upvote, upvotes, downvotes);
        _checkProposalThreshold();
    }

    function _checkProposalThreshold() internal {
        uint256 totalMembers = getCommunityMemberCount();
        if (totalMembers == 0) return;
        uint256 upvotes = proposalVoteTally.counts[1];
        
        if (upvotes * 10000 >= totalMembers * governanceParams.proposalApprovalThreshold) {
            emit StateTransition(state, ProjectState.COUNCIL_REVIEW);
            state = ProjectState.COUNCIL_REVIEW;
            return;
        }
    }

    function councilDecision(AwardDecision decision, string calldata reason, bytes[] calldata signatures)
        external onlyState(ProjectState.COUNCIL_REVIEW)
    {
        _verifyCouncilSignatures(keccak256(abi.encode("councilDecision", decision, reason, councilNonce)), signatures);
        councilNonce++;

        if (decision == AwardDecision.APPROVE) {
            _transition(ProjectState.TENDERING);
        } else if (decision == AwardDecision.REQUEST_REVISION) {
            _transition(ProjectState.PROPOSED);
            proposalVoteDeadline = block.timestamp + governanceParams.proposalVotingWindow;
        } else if (decision == AwardDecision.CLOSE) {
            _transition(ProjectState.CLOSED);
        }
    }

    function publishTender(VisibilityMode _visibility, address[] calldata _targetCommunities, bytes[] calldata signatures)
        external onlyState(ProjectState.TENDERING)
    {
        _verifyCouncilSignatures(keccak256(abi.encode("publishTender", _visibility, _targetCommunities, councilNonce)), signatures);
        councilNonce++;
        visibility = _visibility;
        targetCommunities = _targetCommunities;
    }

    function submitBid(BidData calldata bid) external onlyState(ProjectState.TENDERING) {
        require(bids[msg.sender].totalCost == 0, "Already submitted bid");
        bids[msg.sender] = bid;
        bidderList.push(msg.sender);
        emit BidSubmitted(msg.sender, bid.totalCost, bid.ipfsBidDocument);
    }

    function awardContract(address contractor, MilestoneDefinition[] calldata _milestones, bytes[] calldata signatures)
        external onlyState(ProjectState.TENDERING)
    {
        require(bids[contractor].totalCost > 0, "Contractor has no bid");
        _verifyCouncilSignatures(keccak256(abi.encode("awardContract", contractor, _milestones, councilNonce)), signatures);
        councilNonce++;

        totalEscrowRequired = milestones.initializeMilestones(_milestones);
        require(bids[contractor].totalCost == totalEscrowRequired, "Milestones sum must equal bid total");
        escrowLedger.initializeMilestoneBalances(milestones);
        awardedContractor = contractor;

        _transition(ProjectState.AWARDED);
    }

    function acceptAward() external onlyState(ProjectState.AWARDED) onlyContractor {
        emit AwardAccepted(awardedContractor);
    }

    function fundEscrow(uint256 amount, address token) external nonReentrant onlyState(ProjectState.AWARDED) {
        require(token == escrowToken, "Wrong token");
        require(amount == totalEscrowRequired, "Amount must match total project value");
        escrowLedger.deposit(amount, token);
        _transition(ProjectState.ACTIVE);
        emit EscrowFunded(msg.sender, amount, token);
    }

    function requestPortionGrant(uint256 amount, string calldata ipfsPurpose)
        external onlyState(ProjectState.ACTIVE) onlyContractor
    {
        require(!portionGrantRequested, "Grant already requested");
        require(amount <= (totalEscrowRequired * governanceParams.portionGrantMaxPercent) / 100, "Exceeds max grant");
        portionGrantAmount = amount;
        portionGrantRequested = true;
        emit PortionGrantRequested(msg.sender, amount);
    }

    function approvePortionGrant(bytes[] calldata signatures)
        external onlyState(ProjectState.ACTIVE)
    {
        require(portionGrantRequested && !portionGrantApproved, "Invalid grant state");
        _verifyCouncilSignatures(keccak256(abi.encode("approvePortionGrant", portionGrantAmount, councilNonce)), signatures);
        councilNonce++;
        portionGrantApproved = true;
        
        escrowLedger.releaseMilestone(0, awardedContractor, portionGrantAmount, escrowToken);
        emit PortionGrantApproved(portionGrantAmount);
    }

    function submitMilestoneCompletion(uint8 milestoneIndex, string calldata ipfsEvidence)
        external onlyState(ProjectState.ACTIVE) onlyContractor
    {
        milestones.claimMilestone(currentMilestoneIndex, milestoneIndex, ipfsEvidence);
        _transition(ProjectState.MILESTONE_UNDER_REVIEW);
        emit MilestoneClaimSubmitted(milestoneIndex, ipfsEvidence);
    }

    function signMilestone(uint8 milestoneIndex) external onlyState(ProjectState.MILESTONE_UNDER_REVIEW) {
        require(_isCouncilMember(msg.sender), "Not a council member");
        uint8 numSigs = milestones.signMilestone(milestoneSignatures, milestoneIndex, msg.sender);
        emit MilestoneSigned(milestoneIndex, msg.sender, numSigs);

        if (numSigs >= milestones[milestoneIndex].signaturesRequired) {
            _releaseMilestonePayment(milestoneIndex);
        }
    }

    function castMilestoneVote(uint8 milestoneIndex, uint8 choice)
        external onlyState(ProjectState.MILESTONE_UNDER_REVIEW) onlyMember
    {
        require(choice == 1 || choice == 2, "Invalid choice"); // 1=Yes, 2=No
        Voting.castVote(milestoneVotes[milestoneIndex], milestoneTallies[milestoneIndex], msg.sender, choice);
        
        uint256 threshold = governanceParams.proposalApprovalThreshold;
        uint256 totalMembers = getCommunityMemberCount();
        
        if (Voting.meetsThreshold(milestoneTallies[milestoneIndex].counts[1], totalMembers, threshold)) {
            _releaseMilestonePayment(milestoneIndex);
        } else if (Voting.meetsThreshold(milestoneTallies[milestoneIndex].counts[2], totalMembers, threshold)) {
            milestones.rejectMilestone(milestoneIndex);
            _transition(ProjectState.ACTIVE);
        }
    }

    function castCompletionVote(VoteChoice choice) external onlyState(ProjectState.COMPLETION_VOTE) onlyMember {
        require(block.timestamp <= completionVoteDeadline, "Vote window closed");
        require(!completionVoteCast, "Already voted");
        
        uint8 choiceVal = choice == VoteChoice.COMPLETED ? 1 : (choice == VoteChoice.DISPUTE ? 3 : 2);
        Voting.castVote(completionVotes, completionVoteTally, msg.sender, choiceVal);
        
        uint256 totalMembers = getCommunityMemberCount();
        uint256 threshold = governanceParams.proposalApprovalThreshold;
        
        VoteOutcome outcome = Voting.getResult(completionVoteTally, totalMembers, threshold, 1, 2, 3);
        if (outcome == VoteOutcome.APPROVED) {
            completionVoteCast = true;
            escrowLedger.releaseAll(awardedContractor, escrowToken);
            _transition(ProjectState.COMPLETED);
        } else if (outcome == VoteOutcome.DISPUTED) {
            completionVoteCast = true;
            _transition(ProjectState.DISPUTED);
        }
    }

    function raiseDispute(string calldata reason) external {
        require(msg.sender == awardedContractor || ICommunityRegistry_isMember(communityRegistry, msg.sender), "Unauthorized");
        require(!disputeActive, "Dispute already active");
        disputeActive = true;
        disputeReason = reason;
        disputeRaisedBy = msg.sender;
        
        if (state != ProjectState.COMPLETION_VOTE && state != ProjectState.COMPLETED) {
            escrowLedger.freeze();
            _transition(ProjectState.DISPUTED);
        }
        emit DisputeRaised(msg.sender, reason);
    }

    function executeMediationRuling(MediationRuling calldata ruling) external onlyMediationKey nonReentrant {
        require(state == ProjectState.DISPUTED, "Not in dispute");
        
        if (escrowLedger.frozen) {
            escrowLedger.unfreeze();
        }
        
        uint256 available = escrowLedger.remainingBalance();
        require(ruling.contractorAmount + ruling.funderRefund <= available, "Exceeds balance");

        if (ruling.contractorAmount > 0) {
            IERC20(escrowToken).safeTransfer(ruling.contractor, ruling.contractorAmount);
            escrowLedger.totalReleased += ruling.contractorAmount;
        }
        if (ruling.funderRefund > 0) {
            IERC20(escrowToken).safeTransfer(ruling.funder, ruling.funderRefund);
            escrowLedger.totalReleased += ruling.funderRefund;
        }

        _transition(ProjectState.COMPLETED);
        emit MediationRulingExecuted(ruling);
    }

    function _releaseMilestonePayment(uint8 milestoneIndex) internal nonReentrant {
        bool allPaid = milestones.completeMilestone(milestoneIndex);
        uint256 payment = milestones[milestoneIndex].value;

        if (milestoneIndex == 0 && portionGrantApproved) {
            payment = payment > portionGrantAmount ? payment - portionGrantAmount : 0;
        }

        if (payment > 0) {
            escrowLedger.releaseMilestone(milestoneIndex, awardedContractor, payment, escrowToken);
        }
        emit MilestonePaid(milestoneIndex, awardedContractor, payment);
        
        currentMilestoneIndex++;
        if (allPaid) {
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

    function _verifyCouncilSignatures(bytes32 messageHash, bytes[] calldata signatures) internal view {
        require(signatures.length >= councilThreshold, "Insufficient signatures");
        bytes32 ethHash = messageHash.toEthSignedMessageHash();
        address[] memory recovered = new address[](signatures.length);
        uint8 validCount = 0;
        for (uint256 i = 0; i < signatures.length; i++) {
            address signer = ethHash.recover(signatures[i]);
            for (uint256 j = 0; j < councilSigners.length; j++) {
                if (councilSigners[j] == signer) {
                    bool duplicate = false;
                    for (uint256 k = 0; k < validCount; k++) {
                        if (recovered[k] == signer) { duplicate = true; break; }
                    }
                    if (!duplicate) { recovered[validCount++] = signer; break; }
                }
            }
        }
        require(validCount >= councilThreshold, "Not enough valid council signatures");
    }

    function ICommunityRegistry_isMember(address registry, address user) internal view returns (bool) {
        (bool success, bytes memory data) = registry.staticcall(
            abi.encodeWithSignature("isMember(address)", user)
        );
        if (!success || data.length == 0) return false;
        return abi.decode(data, (bool));
    }

    function getCommunityMemberCount() internal view returns (uint256) {
        (bool success, bytes memory data) = communityRegistry.staticcall(
            abi.encodeWithSignature("getMemberCount()")
        );
        if (!success || data.length == 0) return 0;
        return abi.decode(data, (uint256));
    }

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

    function getProposalVoteCounts() external view returns (uint256 upvotes, uint256 downvotes) {
        return (proposalVoteTally.counts[1], proposalVoteTally.counts[2]);
    }

    function getCompletionVoteCounts() external view returns (uint256 approved, uint256 rejected, uint256 disputed) {
        return (completionVoteTally.counts[1], completionVoteTally.counts[2], completionVoteTally.counts[3]);
    }
}
