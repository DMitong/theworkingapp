// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./IDataTypes.sol";

/// @title ICommunityRegistry
/// @notice Interface for a deployed community's on-chain registry contract.
interface ICommunityRegistry is IDataTypes {
    // ─── Events ──────────────────────────────────────────────────────────────

    event MemberRegistered(address indexed user, MemberRole role);
    event MemberApproved(address indexed user);
    event MemberRemoved(address indexed user);
    event ProjectDeployed(address indexed projectContract, bytes32 indexed proposalHash);
    event GovernanceUpdated(GovernanceParams params);
    event CouncilDecisionRecorded(address indexed projectContract, AwardDecision decision, string reason);

    // ─── Functions ───────────────────────────────────────────────────────────

    /// @notice Submit a membership application. Behaviour depends on verificationMode.
    function applyForMembership(bytes calldata proofData) external;

    /// @notice Council approves a pending membership application.
    function approveMember(address user, bytes[] calldata councilSignatures) external;

    /// @notice Council removes a member.
    function removeMember(address user, bytes[] calldata councilSignatures) external;

    /// @notice Deploy a new ProjectContract child. Only callable by council (multisig verified).
    function deployProject(
        string calldata ipfsProposalHash,
        MilestoneDefinition[] calldata milestones,
        address escrowToken,
        VisibilityMode visibility,
        address[] calldata targetCommunities,
        bytes[] calldata councilSignatures
    ) external returns (address projectContract);

    /// @notice Update governance parameters. Only callable by council multisig.
    function updateGovernanceParams(GovernanceParams calldata params, bytes[] calldata councilSignatures) external;

    /// @notice Returns true if address is a registered member.
    function isMember(address user) external view returns (bool);

    /// @notice Returns member role.
    function getMemberRole(address user) external view returns (MemberRole);

    /// @notice Returns all deployed project contract addresses.
    function getProjectIndex() external view returns (address[] memory);

    /// @notice Returns current governance parameters.
    function getGovernanceParams() external view returns (GovernanceParams memory);

    /// @notice Returns current council configuration.
    function getCouncilConfig() external view returns (CouncilConfig memory);

    /// @notice Returns total active member count.
    function getMemberCount() external view returns (uint256);
}
