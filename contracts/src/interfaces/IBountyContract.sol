// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./IDataTypes.sol";

/// @title IBountyContract
/// @notice Interface for individual bounty contracts (Open Track).
interface IBountyContract is IDataTypes {
    event BountyCreated(address indexed creator, string ipfsHash, VisibilityMode visibility);
    event BidSubmitted(address indexed bidder, uint256 amount, string ipfsBidHash);
    event BidSelected(address indexed contractor);
    event EscrowFunded(address indexed funder, uint256 amount);
    event MilestoneClaimSubmitted(uint8 indexed milestoneIndex, string ipfsEvidence);
    event MilestoneApproved(uint8 indexed milestoneIndex, uint256 amountReleased);
    event MilestoneRejected(uint8 indexed milestoneIndex);
    event BountyCompleted(address indexed contractor, uint256 totalPaid);
    event DisputeRaised(address indexed raisedBy, string reason);
    event MediationRulingExecuted(MediationRuling ruling);

    function submitBid(BidData calldata bid) external;
    function selectBid(address contractor) external;
    function fundEscrow(uint256 amount, address token) external;
    function submitMilestoneCompletion(uint8 milestoneIndex, string calldata ipfsEvidence) external;

    /// @notice Creator approves a milestone. Final milestone also requires completion panel vote.
    function approveMilestone(uint8 milestoneIndex) external;

    /// @notice Panel member (for final milestone) casts approval vote.
    function castPanelVote(uint8 milestoneIndex, bool approved) external;

    function raiseDispute(string calldata reason) external;
    function executeMediationRuling(MediationRuling calldata ruling) external;

    function getState() external view returns (ProjectState);
    function getMilestones() external view returns (MilestoneDefinition[] memory);
    function getEscrowBalance() external view returns (uint256);
}
