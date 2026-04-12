// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./IDataTypes.sol";

/// @title IPlatformNFTRegistry
/// @notice Interface for the soulbound platform identity NFT registry.
interface IPlatformNFTRegistry is IDataTypes {
    // ─── Events ──────────────────────────────────────────────────────────────

    event NFTMinted(address indexed user, uint256 indexed tokenId, string handle);
    event KYCHashSet(uint256 indexed tokenId, bytes32 kycHash);
    event MembershipAdded(uint256 indexed tokenId, address indexed community, MemberRole role);
    event MembershipRemoved(uint256 indexed tokenId, address indexed community);
    event ReputationUpdated(uint256 indexed tokenId, uint256 newScore);

    // ─── Functions ───────────────────────────────────────────────────────────

    /// @notice Mint a new soulbound NFT to a user. Only callable by PlatformFactory.
    function mint(address user, string calldata handle) external returns (uint256 tokenId);

    /// @notice Write a ZK-KYC proof hash to a user's NFT. Only callable by KYC oracle.
    function setKYCHash(uint256 tokenId, bytes32 hash) external;

    /// @notice Add a community membership to a user's NFT. Only callable by registered CommunityRegistry.
    function addCommunityMembership(uint256 tokenId, address community, MemberRole role) external;

    /// @notice Remove a community membership. Only callable by the relevant CommunityRegistry.
    function removeCommunityMembership(uint256 tokenId, address community) external;

    /// @notice Update reputation scores after a project event. Only callable by Project/Bounty contracts.
    function updateReputation(uint256 tokenId, ReputationUpdate calldata update) external;

    /// @notice Returns true if the token holds a valid KYC hash.
    function isVerified(uint256 tokenId) external view returns (bool);

    /// @notice Returns true if the token is currently a member of the given community.
    function isMember(uint256 tokenId, address community) external view returns (bool);

    /// @notice Returns the token ID for a given wallet address. Returns 0 if not registered.
    function getTokenId(address user) external view returns (uint256);

    /// @notice Returns all community addresses the user is a member of.
    function getMemberships(uint256 tokenId) external view returns (address[] memory);

    /// @notice Returns the on-chain reputation score (0–10000 basis points).
    function getReputationScore(uint256 tokenId) external view returns (uint256);
}
