// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/IBountyContract.sol";
import "./libraries/Escrow.sol";
import "./libraries/MilestoneManager.sol";

contract BountyContract is IBountyContract, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Escrow for Escrow.Ledger;
    using MilestoneManager for MilestoneDefinition[];

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

    Escrow.Ledger private escrowLedger;

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
    bool public paused;

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
        panelRequired = uint8((_completionPanel.length / 2) + 1);

        totalEscrowRequired = milestones.initializeMilestones(_milestones);

        state = ProjectState.TENDERING;
        emit BountyCreated(_creator, _ipfsBountyHash, _visibility);
    }

    // ─── Modifiers ────────────────────────────────────────────────────────────

    modifier onlyCreator() { require(msg.sender == creator, "Only creator"); _; }
    modifier onlyContractor() { require(msg.sender == selectedContractor, "Only contractor"); _; }
    modifier onlyMediationKey() { require(msg.sender == mediationKey, "Only mediation key"); _; }
    modifier whenNotPaused() { require(!paused, "Paused"); _; }

    // ─── Bidding ──────────────────────────────────────────────────────────────

    function submitBid(BidData calldata bid) external whenNotPaused {
        require(state == ProjectState.TENDERING, "Not in bidding phase");
        require(bids[msg.sender].totalCost == 0, "Already bid");
        bids[msg.sender] = bid;
        bidderList.push(msg.sender);
        emit BidSubmitted(msg.sender, bid.totalCost, bid.ipfsBidDocument);
    }

    function selectBid(address contractor) external onlyCreator whenNotPaused {
        require(state == ProjectState.TENDERING, "Not in bidding phase");
        require(bids[contractor].totalCost > 0, "No bid from contractor");
        
        uint256 requiredForBid = bids[contractor].totalCost;
        require(requiredForBid == totalEscrowRequired, "Milestones sum must equal bid total");
        
        escrowLedger.initializeMilestoneBalances(milestones);
        selectedContractor = contractor;
        state = ProjectState.AWARDED;
        emit BidSelected(contractor);
    }

    function fundEscrow(uint256 amount, address token) external nonReentrant whenNotPaused {
        require(state == ProjectState.AWARDED, "Not in awarded state");
        require(token == escrowToken, "Wrong token");
        require(amount == totalEscrowRequired, "Amount must match total");
        
        escrowLedger.deposit(amount, token);
        state = ProjectState.ACTIVE;
        emit EscrowFunded(msg.sender, amount);
    }

    // ─── Milestone execution ──────────────────────────────────────────────────

    function submitMilestoneCompletion(uint8 milestoneIndex, string calldata ipfsEvidence)
        external onlyContractor whenNotPaused
    {
        require(state == ProjectState.ACTIVE, "Not active");
        milestones.claimMilestone(currentMilestoneIndex, milestoneIndex, ipfsEvidence);
        emit MilestoneClaimSubmitted(milestoneIndex, ipfsEvidence);
    }

    function approveMilestone(uint8 milestoneIndex) external onlyCreator whenNotPaused {
        require(milestones[milestoneIndex].state == MilestoneState.UNDER_REVIEW, "Not under review");
        bool isFinal = milestoneIndex == milestones.length - 1;

        if (isFinal && completionPanel.length > 0) {
            revert("Final milestone requires panel vote - use castPanelVote");
        }

        _releaseMilestone(milestoneIndex);
    }

    function castPanelVote(uint8 milestoneIndex, bool approved) external whenNotPaused {
        require(milestones[milestoneIndex].state == MilestoneState.UNDER_REVIEW, "Not under review");
        bool isFinal = milestoneIndex == milestones.length - 1;
        require(isFinal, "Panel vote only for final milestone");

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

    function raiseDispute(string calldata reason) external whenNotPaused {
        require(msg.sender == creator || msg.sender == selectedContractor, "Unauthorized");
        require(!disputeActive, "Dispute already active");
        disputeActive = true;
        
        if (state != ProjectState.COMPLETED) {
            escrowLedger.freeze();
            state = ProjectState.DISPUTED;
        }
        
        emit DisputeRaised(msg.sender, reason);
    }

    function executeMediationRuling(MediationRuling calldata ruling) external onlyMediationKey nonReentrant whenNotPaused {
        require(state == ProjectState.DISPUTED, "Not disputed");
        
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

        state = ProjectState.COMPLETED;
        emit MediationRulingExecuted(ruling);
    }

    // ─── Internal ─────────────────────────────────────────────────────────────

    function _releaseMilestone(uint8 milestoneIndex) internal nonReentrant {
        bool allPaid = milestones.completeMilestone(milestoneIndex);
        uint256 payment = milestones[milestoneIndex].value;
        
        if (payment > 0) {
            escrowLedger.releaseMilestone(milestoneIndex, selectedContractor, payment, escrowToken);
        }
        emit MilestoneApproved(milestoneIndex, payment);
        
        currentMilestoneIndex++;
        if (allPaid) {
            state = ProjectState.COMPLETED;
            emit BountyCompleted(selectedContractor, totalEscrowRequired);
        } else {
            state = ProjectState.ACTIVE;
        }
    }

    // ─── Views ────────────────────────────────────────────────────────────────

    function getState() external view returns (ProjectState) { return state; }
    function getMilestones() external view returns (MilestoneDefinition[] memory) { return milestones; }
    function getEscrowBalance() external view returns (uint256) { return IERC20(escrowToken).balanceOf(address(this)); }

    function setPaused(bool value) external {
        require(msg.sender == platformFactory, "Only factory");
        paused = value;
    }
}
