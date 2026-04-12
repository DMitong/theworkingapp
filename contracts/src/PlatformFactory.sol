// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./interfaces/IDataTypes.sol";
import "./PlatformNFTRegistry.sol";
import "./CommunityRegistry.sol";
import "./BountyContract.sol";

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
        require(registry != address(0), "Invalid registry");
        nftRegistry = PlatformNFTRegistry(registry);
        emit NFTRegistrySet(registry);
    }

    function setMediationKey(address key) external onlyOwner {
        require(key != address(0), "Invalid key");
        mediationKey = key;
        emit MediationKeyUpdated(key);
    }

    function pause() external onlyOwner {
        _pause();
        _syncChildPause(true);
    }

    function unpause() external onlyOwner {
        _unpause();
        _syncChildPause(false);
    }

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
        require(address(nftRegistry) != address(0), "NFT registry not set");
        require(bytes(name).length > 0, "Invalid name");
        _validateCouncilConfig(councilConfig);
        _validateGovernanceParams(governanceParams);

        CouncilConfig memory councilConfigMemory = _copyCouncilConfig(councilConfig);
        GovernanceParams memory governanceParamsMemory = _copyGovernanceParams(governanceParams);

        bytes32 salt = keccak256(abi.encodePacked(msg.sender, name, block.timestamp));
        bytes memory initCode = abi.encodePacked(
            type(CommunityRegistry).creationCode,
            abi.encode(
                name,
                "GENERAL",
                address(this),
                address(nftRegistry),
                councilConfigMemory,
                governanceParamsMemory
            )
        );

        communityRegistry = _computeCreate2Address(salt, keccak256(initCode));
        nftRegistry.registerCommunity(communityRegistry);

        CommunityRegistry deployedCommunity = new CommunityRegistry{salt: salt}(
            name,
            "GENERAL",
            address(this),
            address(nftRegistry),
            councilConfigMemory,
            governanceParamsMemory
        );

        communityRegistry = address(deployedCommunity);
        deployedCommunities.push(communityRegistry);
        isCommunity[communityRegistry] = true;

        emit CommunityDeployed(communityRegistry, msg.sender, name);
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
        require(address(nftRegistry) != address(0), "NFT registry not set");
        require(bytes(ipfsBountyHash).length > 0, "Invalid bounty hash");
        require(escrowToken != address(0), "Invalid escrow token");
        require(milestones.length > 0, "No milestones");

        MilestoneDefinition[] memory milestonesMemory = _copyMilestones(milestones);
        address[] memory targetsMemory = _copyAddressArray(targetCommunities);
        address[] memory completionPanel = new address[](0);

        BountyContract bounty = new BountyContract(
            msg.sender,
            address(this),
            mediationKey,
            ipfsBountyHash,
            milestonesMemory,
            escrowToken,
            visibility,
            targetsMemory,
            completionPanel
        );

        bountyContract = address(bounty);
        deployedBounties.push(bountyContract);
        isBountyContract[bountyContract] = true;
        nftRegistry.registerBountyContract(bountyContract);

        emit BountyDeployed(bountyContract, msg.sender);
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

    function _validateCouncilConfig(CouncilConfig calldata councilConfig) internal pure {
        require(councilConfig.signers.length > 0, "No council signers");
        require(councilConfig.threshold > 0, "Invalid council threshold");
        require(councilConfig.threshold <= councilConfig.signers.length, "Threshold exceeds signers");

        for (uint256 i = 0; i < councilConfig.signers.length; i++) {
            require(councilConfig.signers[i] != address(0), "Invalid council signer");
            for (uint256 j = i + 1; j < councilConfig.signers.length; j++) {
                require(councilConfig.signers[i] != councilConfig.signers[j], "Duplicate council signer");
            }
        }
    }

    function _validateGovernanceParams(GovernanceParams calldata governanceParams) internal pure {
        require(governanceParams.proposalApprovalThreshold <= 10_000, "Invalid approval threshold");
        require(governanceParams.minMembers > 0, "Invalid min members");
        require(governanceParams.portionGrantMaxPercent <= 100, "Invalid grant max");
        require(governanceParams.tier2Threshold >= governanceParams.tier1Threshold, "Invalid tier thresholds");
    }

    function _copyCouncilConfig(CouncilConfig calldata councilConfig) internal pure returns (CouncilConfig memory config) {
        address[] memory signers = _copyAddressArray(councilConfig.signers);
        config = CouncilConfig({ signers: signers, threshold: councilConfig.threshold });
    }

    function _copyGovernanceParams(
        GovernanceParams calldata governanceParams
    ) internal pure returns (GovernanceParams memory params) {
        params = GovernanceParams({
            proposalApprovalThreshold: governanceParams.proposalApprovalThreshold,
            proposalVotingWindow: governanceParams.proposalVotingWindow,
            completionVoteWindow: governanceParams.completionVoteWindow,
            bidWindow: governanceParams.bidWindow,
            councilReviewWindow: governanceParams.councilReviewWindow,
            tier1Threshold: governanceParams.tier1Threshold,
            tier2Threshold: governanceParams.tier2Threshold,
            minMembers: governanceParams.minMembers,
            portionGrantMaxPercent: governanceParams.portionGrantMaxPercent,
            verificationMode: governanceParams.verificationMode
        });
    }

    function _copyMilestones(
        MilestoneDefinition[] calldata milestones
    ) internal pure returns (MilestoneDefinition[] memory milestonesMemory) {
        milestonesMemory = new MilestoneDefinition[](milestones.length);
        for (uint256 i = 0; i < milestones.length; i++) {
            require(milestones[i].value > 0, "Invalid milestone value");
            milestonesMemory[i] = milestones[i];
        }
    }

    function _copyAddressArray(address[] calldata input) internal pure returns (address[] memory output) {
        output = new address[](input.length);
        for (uint256 i = 0; i < input.length; i++) {
            output[i] = input[i];
        }
    }

    function _computeCreate2Address(bytes32 salt, bytes32 initCodeHash) internal view returns (address predicted) {
        predicted = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff),
                            address(this),
                            salt,
                            initCodeHash
                        )
                    )
                )
            )
        );
    }

    function _syncChildPause(bool pausedState) internal {
        for (uint256 i = 0; i < deployedCommunities.length; i++) {
            (bool success, ) = deployedCommunities[i].call(
                abi.encodeWithSignature("setPaused(bool)", pausedState)
            );
            require(success, "Community pause sync failed");
        }

        for (uint256 i = 0; i < deployedBounties.length; i++) {
            (bool success, ) = deployedBounties[i].call(
                abi.encodeWithSignature("setPaused(bool)", pausedState)
            );
            require(success, "Bounty pause sync failed");
        }
    }
}
