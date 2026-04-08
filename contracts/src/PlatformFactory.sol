// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./interfaces/IDataTypes.sol";
import "./PlatformNFTRegistry.sol";

/// @title PlatformFactory
/// @notice Root factory contract. Deployed once per chain.
///         Deploys CommunityRegistry and BountyContract instances from audited templates.
///         Owns the PlatformNFTRegistry and holds the mediation key reference.
/// @dev    See contracts/BUILD.md — Step 4 for full implementation notes.
contract PlatformFactory is Ownable, Pausable, IDataTypes {
    // ─── Events ───────────────────────────────────────────────────────────────

    event CommunityDeployed(address indexed communityRegistry, address indexed founder, string name);
    event BountyDeployed(address indexed bountyContract, address indexed creator);
    event MediationKeyUpdated(address indexed newKey);
    event NFTRegistrySet(address indexed registry);

    // ─── State ────────────────────────────────────────────────────────────────

    PlatformNFTRegistry public nftRegistry;

    /// @notice The platform mediation address — a company-controlled hardware multisig (Gnosis Safe).
    address public mediationKey;

    address[] public deployedCommunities;
    address[] public deployedBounties;

    /// @dev Registered community addresses — used by NFT registry for access control.
    mapping(address => bool) public isCommunity;
    mapping(address => bool) public isBountyContract;

    // ─── Constructor ──────────────────────────────────────────────────────────

    constructor(address _mediationKey) Ownable(msg.sender) {
        require(_mediationKey != address(0), "Invalid mediation key");
        mediationKey = _mediationKey;
    }

    // ─── Admin ────────────────────────────────────────────────────────────────

    function setNFTRegistry(address registry) external onlyOwner {
        nftRegistry = PlatformNFTRegistry(registry);
        emit NFTRegistrySet(registry);
    }

    function setMediationKey(address key) external onlyOwner {
        require(key != address(0), "Invalid key");
        mediationKey = key;
        emit MediationKeyUpdated(key);
    }

    function pause() external onlyOwner { _pause(); }
    function unpause() external onlyOwner { _unpause(); }

    // ─── Minting (called by backend on user registration) ─────────────────────

    /// @notice Mint a platform NFT to a new user. Only callable by owner (backend relay).
    function mintPlatformNFT(address user, string calldata handle) external onlyOwner whenNotPaused returns (uint256) {
        return nftRegistry.mint(user, handle);
    }

    // ─── Community Deployment ─────────────────────────────────────────────────

    /// @notice Deploy a new CommunityRegistry for a community.
    /// @dev    TODO: Implement. Import CommunityRegistry contract and deploy with CREATE2.
    ///         Use keccak256(abi.encodePacked(founder, name, block.timestamp)) as salt.
    ///         After deploy: call nftRegistry.registerCommunity(newCommunity).
    ///         Record in deployedCommunities and isCommunity mapping.
    ///         Emit CommunityDeployed.
    function deployCommunity(
        string calldata name,
        CouncilConfig calldata councilConfig,
        GovernanceParams calldata governanceParams
    ) external whenNotPaused returns (address communityRegistry) {
        // TODO: Implement community deployment
        // See BUILD.md Step 4 for full spec
        revert("Not implemented — see BUILD.md Step 4");
    }

    // ─── Bounty Deployment ────────────────────────────────────────────────────

    /// @notice Deploy a new BountyContract for an individual bounty.
    /// @dev    TODO: Implement. Import BountyContract and deploy.
    ///         Record in deployedBounties and isBountyContract.
    ///         Emit BountyDeployed.
    function deployBounty(
        string calldata ipfsBountyHash,
        MilestoneDefinition[] calldata milestones,
        address escrowToken,
        VisibilityMode visibility,
        address[] calldata targetCommunities
    ) external whenNotPaused returns (address bountyContract) {
        // TODO: Implement bounty deployment
        // See BUILD.md Step 7 for BountyContract spec
        revert("Not implemented — see BUILD.md Step 7");
    }

    // ─── Views ────────────────────────────────────────────────────────────────

    function getCommunityCount() external view returns (uint256) {
        return deployedCommunities.length;
    }

    function getBountyCount() external view returns (uint256) {
        return deployedBounties.length;
    }

    function getAllCommunities() external view returns (address[] memory) {
        return deployedCommunities;
    }
}
