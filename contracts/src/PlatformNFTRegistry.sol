// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IPlatformNFTRegistry.sol";

/// @title PlatformNFTRegistry
/// @notice Soulbound (non-transferable) ERC-721 that serves as every user's
///         platform identity card. Tracks KYC verification, community memberships,
///         and reputation scores.
/// @dev    Deploy once on the canonical chain (Phase 1: Base or Polygon).
///         See contracts/BUILD.md — Step 3 for full implementation notes.
contract PlatformNFTRegistry is ERC721, Ownable, IPlatformNFTRegistry {
    // ─── State ────────────────────────────────────────────────────────────────

    uint256 private _nextTokenId = 1;

    /// @dev Maps wallet address → tokenId (0 = not registered)
    mapping(address => uint256) public walletToTokenId;

    /// @dev Maps tokenId → platform handle
    mapping(uint256 => string) public handles;

    /// @dev Maps tokenId → ZK-KYC hash (bytes32(0) = not verified)
    mapping(uint256 => bytes32) public kycHashes;

    /// @dev Maps tokenId → list of community registry addresses
    mapping(uint256 => address[]) private _memberships;

    /// @dev Maps tokenId → community address → member role + joined timestamp
    mapping(uint256 => mapping(address => MemberRole)) public memberRoles;
    mapping(uint256 => mapping(address => bool)) public isCommunityMember;

    /// @dev Reputation score 0–10000 basis points
    mapping(uint256 => uint256) public reputationScores;

    /// @dev Counters for reputation display
    mapping(uint256 => uint256) public projectsCompleted;
    mapping(uint256 => uint256) public projectsAwarded;
    mapping(uint256 => uint256) public votesParticipated;
    mapping(uint256 => uint256) public disputeCount;

    /// @dev Access control — which addresses can call privileged functions
    address public platformFactory;
    address public kycOracle;
    mapping(address => bool) public registeredCommunities;
    mapping(address => bool) public registeredProjectContracts;

    // ─── Constructor ──────────────────────────────────────────────────────────

    constructor(address _factory) ERC721("The Working App Identity", "TWAID") Ownable(msg.sender) {
        platformFactory = _factory;
    }

    // ─── Modifiers ────────────────────────────────────────────────────────────

    modifier onlyFactory() {
        require(msg.sender == platformFactory, "Only factory");
        _;
    }

    modifier onlyKYCOracle() {
        require(msg.sender == kycOracle, "Only KYC oracle");
        _;
    }

    modifier onlyCommunity() {
        require(registeredCommunities[msg.sender], "Only registered community");
        _;
    }

    modifier onlyProjectContract() {
        require(registeredProjectContracts[msg.sender], "Only registered project");
        _;
    }

    // ─── Soulbound enforcement ────────────────────────────────────────────────

    /// @dev Override all transfer functions to make this soulbound.
    function transferFrom(address, address, uint256) public pure override {
        revert("Soulbound: non-transferable");
    }

    function safeTransferFrom(address, address, uint256, bytes memory) public pure override {
        revert("Soulbound: non-transferable");
    }

    function approve(address, uint256) public pure override {
        revert("Soulbound: non-transferable");
    }

    function setApprovalForAll(address, bool) public pure override {
        revert("Soulbound: non-transferable");
    }

    // ─── Core functions ───────────────────────────────────────────────────────

    /// @notice Mint a soulbound NFT to a new user. Called by PlatformFactory on registration.
    function mint(address user, string calldata handle) external onlyFactory returns (uint256 tokenId) {
        require(walletToTokenId[user] == 0, "Already registered");
        require(bytes(handle).length > 0 && bytes(handle).length <= 32, "Invalid handle length");

        tokenId = _nextTokenId++;
        _safeMint(user, tokenId);
        walletToTokenId[user] = tokenId;
        handles[tokenId] = handle;

        emit NFTMinted(user, tokenId, handle);
    }

    /// @notice Set ZK-KYC hash. Called by the platform KYC oracle after off-chain verification.
    function setKYCHash(uint256 tokenId, bytes32 hash) external onlyKYCOracle {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        require(hash != bytes32(0), "Invalid hash");
        kycHashes[tokenId] = hash;
        emit KYCHashSet(tokenId, hash);
    }

    /// @notice Add community membership to a user's NFT.
    function addCommunityMembership(uint256 tokenId, address community, MemberRole role)
        external
        onlyCommunity
    {
        require(!isCommunityMember[tokenId][community], "Already a member");
        _memberships[tokenId].push(community);
        isCommunityMember[tokenId][community] = true;
        memberRoles[tokenId][community] = role;
        emit MembershipAdded(tokenId, community, role);
    }

    /// @notice Remove community membership from a user's NFT.
    function removeCommunityMembership(uint256 tokenId, address community) external onlyCommunity {
        require(isCommunityMember[tokenId][community], "Not a member");
        isCommunityMember[tokenId][community] = false;
        emit MembershipRemoved(tokenId, community);
    }

    /// @notice Update reputation counters. Called by project/bounty contracts after events.
    function updateReputation(uint256 tokenId, ReputationUpdate calldata update) external onlyProjectContract {
        if (update.projectCompleted) {
            projectsCompleted[tokenId]++;
            // Weighted running average: new score = (old * completed-1 + newScore) / completed
            uint256 n = projectsCompleted[tokenId];
            reputationScores[tokenId] = (reputationScores[tokenId] * (n - 1) + update.completionVoteScore * 100) / n;
        }
        if (update.projectAwarded) projectsAwarded[tokenId]++;
        if (update.projectDisputed) disputeCount[tokenId]++;
        emit ReputationUpdated(tokenId, reputationScores[tokenId]);
    }

    // ─── View functions ───────────────────────────────────────────────────────

    function isVerified(uint256 tokenId) external view returns (bool) {
        return kycHashes[tokenId] != bytes32(0);
    }

    function isMember(address user, address community) external view returns (bool) {
        uint256 tokenId = walletToTokenId[user];
        if (tokenId == 0) return false;
        return isCommunityMember[tokenId][community];
    }

    function getTokenId(address user) external view returns (uint256) {
        return walletToTokenId[user];
    }

    function getMemberships(uint256 tokenId) external view returns (address[] memory) {
        return _memberships[tokenId];
    }

    function getReputationScore(uint256 tokenId) external view returns (uint256) {
        return reputationScores[tokenId];
    }

    // ─── Admin ────────────────────────────────────────────────────────────────

    function setKYCOracle(address oracle) external onlyOwner {
        kycOracle = oracle;
    }

    function registerCommunity(address community) external onlyFactory {
        registeredCommunities[community] = true;
    }

    function registerProjectContract(address project) external {
        require(registeredCommunities[msg.sender], "Only registered community");
        registeredProjectContracts[project] = true;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        // TODO: Return base64-encoded JSON pointing to off-chain metadata API.
        // The API at /api/v1/nft/{tokenId}/metadata assembles dynamic metadata
        // from on-chain state (memberships, reputation, kyc status) and signs it.
        return string(abi.encodePacked("https://api.theworkingapp.io/v1/nft/", _toString(tokenId), "/metadata"));
    }

    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) { digits++; temp /= 10; }
        bytes memory buffer = new bytes(digits);
        while (value != 0) { digits--; buffer[digits] = bytes1(uint8(48 + uint256(value % 10))); value /= 10; }
        return string(buffer);
    }
}
