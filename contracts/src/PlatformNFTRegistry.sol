// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./interfaces/IPlatformNFTRegistry.sol";

/// @title PlatformNFTRegistry
/// @notice Soulbound (non-transferable) ERC-721 that serves as every user's
///         platform identity card. Tracks KYC verification, community memberships,
///         and reputation scores.
/// @dev    Deploy once on the canonical chain (Phase 1: Base or Polygon).
///         See contracts/BUILD.md — Step 3 for full implementation notes.
contract PlatformNFTRegistry is ERC721, Ownable, IPlatformNFTRegistry {
    using Strings for uint256;

    // ─── State ────────────────────────────────────────────────────────────────

    uint256 private _nextTokenId = 1;

    /// @dev Maps wallet address → tokenId (0 = not registered)
    mapping(address => uint256) public walletToTokenId;

    /// @dev Maps tokenId → platform handle
    mapping(uint256 => string) public handles;
    mapping(bytes32 => bool) private _reservedHandles;

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
    mapping(address => bool) public registeredReputationContracts;

    event KYCOracleUpdated(address indexed oracle);
    event CommunityRegistered(address indexed community, bool active);
    event ReputationContractRegistered(address indexed reputationContract, bool active);

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
        require(registeredReputationContracts[msg.sender], "Only registered reputation contract");
        _;
    }

    modifier onlyFactoryAuthority() {
        require(msg.sender == platformFactory || msg.sender == owner(), "Only factory authority");
        _;
    }

    modifier onlyRegistryAuthority() {
        require(
            msg.sender == platformFactory || msg.sender == owner() || registeredCommunities[msg.sender],
            "Only registry authority"
        );
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
        require(_isValidHandle(handle), "Invalid handle");

        bytes32 handleHash = keccak256(bytes(handle));
        require(!_reservedHandles[handleHash], "Handle already taken");

        tokenId = _nextTokenId++;
        _safeMint(user, tokenId);
        walletToTokenId[user] = tokenId;
        handles[tokenId] = handle;
        _reservedHandles[handleHash] = true;

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
        memberRoles[tokenId][community] = MemberRole.MEMBER;

        address[] storage memberships = _memberships[tokenId];
        for (uint256 i = 0; i < memberships.length; i++) {
            if (memberships[i] == community) {
                memberships[i] = memberships[memberships.length - 1];
                memberships.pop();
                break;
            }
        }

        emit MembershipRemoved(tokenId, community);
    }

    /// @notice Update reputation counters. Called by project/bounty contracts after events.
    function updateReputation(uint256 tokenId, ReputationUpdate calldata update) external onlyProjectContract {
        if (update.projectCompleted) {
            projectsCompleted[tokenId]++;
            // Weighted running average: new score = (old * completed-1 + newScore) / completed
            uint256 n = projectsCompleted[tokenId];
            uint256 newScore = uint256(update.completionVoteScore) * 100;
            reputationScores[tokenId] = (reputationScores[tokenId] * (n - 1) + newScore) / n;
        }
        if (update.projectAwarded) projectsAwarded[tokenId]++;
        if (update.projectDisputed) disputeCount[tokenId]++;
        emit ReputationUpdated(tokenId, reputationScores[tokenId]);
    }

    // ─── View functions ───────────────────────────────────────────────────────

    function isVerified(uint256 tokenId) external view returns (bool) {
        return kycHashes[tokenId] != bytes32(0);
    }

    function isMember(uint256 tokenId, address community) external view returns (bool) {
        return isCommunityMember[tokenId][community];
    }

    function isWalletMember(address user, address community) external view returns (bool) {
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

    function getCommunityCount(uint256 tokenId) external view returns (uint256) {
        return _memberships[tokenId].length;
    }

    // ─── Admin ────────────────────────────────────────────────────────────────

    function setKYCOracle(address oracle) external onlyOwner {
        require(oracle != address(0), "Invalid oracle");
        kycOracle = oracle;
        emit KYCOracleUpdated(oracle);
    }

    function registerCommunity(address community) external onlyFactoryAuthority {
        require(community != address(0), "Invalid community");
        registeredCommunities[community] = true;
        emit CommunityRegistered(community, true);
    }

    function unregisterCommunity(address community) external onlyFactoryAuthority {
        registeredCommunities[community] = false;
        emit CommunityRegistered(community, false);
    }

    function registerProjectContract(address project) external onlyRegistryAuthority {
        require(project != address(0), "Invalid project");
        registeredReputationContracts[project] = true;
        emit ReputationContractRegistered(project, true);
    }

    function registerBountyContract(address bounty) external onlyFactoryAuthority {
        require(bounty != address(0), "Invalid bounty");
        registeredReputationContracts[bounty] = true;
        emit ReputationContractRegistered(bounty, true);
    }

    function unregisterReputationContract(address reputationContract) external onlyFactoryAuthority {
        registeredReputationContracts[reputationContract] = false;
        emit ReputationContractRegistered(reputationContract, false);
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        string memory json = string.concat(
            '{"name":"The Working App Identity #',
            tokenId.toString(),
            '","description":"Soulbound identity card for The Working App.",',
            '"external_url":"',
            _metadataUrl(tokenId),
            '","attributes":',
            _attributesJson(tokenId),
            "}"
        );

        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(json))));
    }

    function _metadataUrl(uint256 tokenId) internal view returns (string memory) {
        return string.concat("https://api.theworkingapp.io/v1/nft/", tokenId.toString(), "/metadata");
    }

    function _attributesJson(uint256 tokenId) internal view returns (string memory) {
        return string.concat(
            "[",
            _handleAttribute(tokenId),
            ",",
            _kycAttribute(tokenId),
            ",",
            _communityCountAttribute(tokenId),
            ",",
            _reputationAttribute(tokenId),
            "]"
        );
    }

    function _handleAttribute(uint256 tokenId) internal view returns (string memory) {
        return string.concat('{"trait_type":"Handle","value":"', handles[tokenId], '"}');
    }

    function _kycAttribute(uint256 tokenId) internal view returns (string memory) {
        return string.concat(
            '{"trait_type":"KYC Verified","value":"',
            _boolString(kycHashes[tokenId] != bytes32(0)),
            '"}'
        );
    }

    function _communityCountAttribute(uint256 tokenId) internal view returns (string memory) {
        return string.concat(
            '{"trait_type":"Community Count","display_type":"number","value":',
            uint256(_memberships[tokenId].length).toString(),
            "}"
        );
    }

    function _reputationAttribute(uint256 tokenId) internal view returns (string memory) {
        return string.concat(
            '{"trait_type":"Reputation Score","display_type":"number","value":',
            reputationScores[tokenId].toString(),
            "}"
        );
    }

    function _isValidHandle(string calldata handle) internal pure returns (bool) {
        bytes calldata data = bytes(handle);
        if (data.length == 0 || data.length > 32) return false;

        for (uint256 i = 0; i < data.length; i++) {
            bytes1 char = data[i];
            bool isNumber = char >= 0x30 && char <= 0x39;
            bool isUpper = char >= 0x41 && char <= 0x5A;
            bool isLower = char >= 0x61 && char <= 0x7A;
            bool isSeparator = char == 0x2D || char == 0x5F || char == 0x2E;

            if (!(isNumber || isUpper || isLower || isSeparator)) {
                return false;
            }
        }

        return true;
    }

    function _boolString(bool value) internal pure returns (string memory) {
        return value ? "Yes" : "No";
    }
}
