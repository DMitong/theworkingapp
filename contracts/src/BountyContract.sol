// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/IBountyContract.sol";

/// @title BountyContract
/// @notice Child contract for individual bounties (Open Track).
///         Simpler lifecycle than ProjectContract — no community governance,
///         creator + optional completion panel verify milestones.
/// @dev    Deployed by PlatformFactory.deployBounty().
///         See contracts/BUILD.md — Step 7 for full implementation notes.
contract BountyContract is IBountyContract, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ─── State ────────────────────────────────────────────────────────────────

    address public immutable creator;
    address public immutable platformFactory;
    address public mediationKey;

    ProjectState public state;
    string public ipfsBountyHash;
    address public escrowToken;
    VisibilityMode public visibility;
    address[] public targetCommunities;

    MilestoneDefinition[] public milestones;
    uint8 public currentMilestoneIndex;
    uint256 public totalEscrowRequired;

    address[] public bidderList;
    mapping(address => BidData) public bids;
    address public selectedContractor;

    // Completion panel for final milestone
    address[] public completionPanel;
    mapping(address => bool) public panelVotes;
    uint8 public panelApprovals;
    uint8 public panelRequired;

    // Dispute
    bool public disputeActive;

    // ─── Constructor ──────────────────────────────────────────────────────────

    constructor(
        address _creator,
        address _factory,
        address _mediationKey,
        string memory _ipfsBountyHash,
        MilestoneDefinition[] memory _milestones,
        address _escrowToken,
        VisibilityMode _visibility,
        address[] memory _targetCommunities,
        address[] memory _completionPanel
    ) {
        creator = _creator;
        platformFactory = _factory;
        mediationKey = _mediationKey;
        ipfsBountyHash = _ipfsBountyHash;
        escrowToken = _escrowToken;
        visibility = _visibility;
        targetCommunities = _targetCommunities;
        completionPanel = _completionPanel;
        panelRequired = uint8((_completionPanel.length / 2) + 1); // Simple majority

        for (uint256 i = 0; i < _milestones.length; i++) {
            milestones.push(_milestones[i]);
            totalEscrowRequired += _milestones[i].value;
        }

        state = ProjectState.TENDERING;
        emit BountyCreated(_creator, _ipfsBountyHash, _visibility);
    }

    // ─── Modifiers ────────────────────────────────────────────────────────────

    modifier onlyCreator() { require(msg.sender == creator, "Only creator"); _; }
    modifier onlyContractor() { require(msg.sender == selectedContractor, "Only contractor"); _; }
    modifier onlyMediationKey() { require(msg.sender == mediationKey, "Only mediation key"); _; }

    // ─── Bidding ──────────────────────────────────────────────────────────────

    function submitBid(BidData calldata bid) external {
        require(state == ProjectState.TENDERING, "Not in bidding phase");
        require(bids[msg.sender].totalCost == 0, "Already bid");
        bids[msg.sender] = bid;
        bidderList.push(msg.sender);
        emit BidSubmitted(msg.sender, bid.totalCost, bid.ipfsBidDocument);
    }

    function selectBid(address contractor) external onlyCreator {
        require(state == ProjectState.TENDERING, "Not in bidding phase");
        require(bids[contractor].totalCost > 0, "No bid from contractor");
        selectedContractor = contractor;
        state = ProjectState.AWARDED;
        emit BidSelected(contractor);
    }

    function fundEscrow(uint256 amount, address token) external nonReentrant {
        require(state == ProjectState.AWARDED, "Not in awarded state");
        require(token == escrowToken, "Wrong token");
        require(amount == totalEscrowRequired, "Amount must match total");
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        state = ProjectState.ACTIVE;
        emit EscrowFunded(msg.sender, amount);
    }

    // ─── Milestone execution ──────────────────────────────────────────────────

    function submitMilestoneCompletion(uint8 milestoneIndex, string calldata ipfsEvidence)
        external onlyContractor
    {
        require(state == ProjectState.ACTIVE, "Not active");
        require(milestoneIndex == currentMilestoneIndex, "Must complete in order");
        milestones[milestoneIndex].ipfsEvidence = ipfsEvidence;
        milestones[milestoneIndex].state = MilestoneState.UNDER_REVIEW;
        emit MilestoneClaimSubmitted(milestoneIndex, ipfsEvidence);
    }

    /// @notice Creator approves a non-final milestone. Panel required for final milestone.
    function approveMilestone(uint8 milestoneIndex) external onlyCreator {
        require(milestones[milestoneIndex].state == MilestoneState.UNDER_REVIEW, "Not under review");
        bool isFinal = milestoneIndex == milestones.length - 1;

        if (isFinal && completionPanel.length > 0) {
            // Final milestone with panel — wait for panel votes too
            // Creator approval counts as one panel vote
            // TODO: Implement proper panel vote collection
            revert("Final milestone requires panel vote - use castPanelVote");
        }

        _releaseMilestone(milestoneIndex);
    }

    function castPanelVote(uint8 milestoneIndex, bool approved) external {
        require(milestones[milestoneIndex].state == MilestoneState.UNDER_REVIEW, "Not under review");
        bool isPanel = false;
        for (uint256 i = 0; i < completionPanel.length; i++) {
            if (completionPanel[i] == msg.sender) { isPanel = true; break; }
        }
        require(isPanel || msg.sender == creator, "Not authorized panel member");
        require(!panelVotes[msg.sender], "Already voted");

        panelVotes[msg.sender] = true;
        if (approved) panelApprovals++;

        if (panelApprovals >= panelRequired) {
            _releaseMilestone(milestoneIndex);
        }
    }

    // ─── Dispute ──────────────────────────────────────────────────────────────

    function raiseDispute(string calldata reason) external {
        require(msg.sender == creator || msg.sender == selectedContractor, "Unauthorized");
        require(!disputeActive, "Dispute already active");
        disputeActive = true;
        state = ProjectState.DISPUTED;
        emit DisputeRaised(msg.sender, reason);
    }

    function executeMediationRuling(MediationRuling calldata ruling) external onlyMediationKey nonReentrant {
        require(state == ProjectState.DISPUTED, "Not disputed");
        if (ruling.contractorAmount > 0) IERC20(escrowToken).safeTransfer(ruling.contractor, ruling.contractorAmount);
        if (ruling.funderRefund > 0) IERC20(escrowToken).safeTransfer(ruling.funder, ruling.funderRefund);
        state = ProjectState.COMPLETED;
        emit MediationRulingExecuted(ruling);
    }

    // ─── Internal ─────────────────────────────────────────────────────────────

    function _releaseMilestone(uint8 milestoneIndex) internal nonReentrant {
        milestones[milestoneIndex].state = MilestoneState.PAID;
        uint256 payment = milestones[milestoneIndex].value;
        IERC20(escrowToken).safeTransfer(selectedContractor, payment);
        emit MilestoneApproved(milestoneIndex, payment);
        currentMilestoneIndex++;
        if (currentMilestoneIndex >= milestones.length) {
            state = ProjectState.COMPLETED;
            emit BountyCompleted(selectedContractor, totalEscrowRequired);
        }
    }

    // ─── Views ────────────────────────────────────────────────────────────────

    function getState() external view returns (ProjectState) { return state; }
    function getMilestones() external view returns (MilestoneDefinition[] memory) { return milestones; }
    function getEscrowBalance() external view returns (uint256) { return IERC20(escrowToken).balanceOf(address(this)); }
}
