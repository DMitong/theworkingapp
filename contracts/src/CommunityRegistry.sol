// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "./interfaces/ICommunityRegistry.sol";
import "./interfaces/IPlatformNFTRegistry.sol";

/// @title CommunityRegistry
/// @notice On-chain registry for a single community. Manages membership, council
///         configuration, governance parameters, and deploys child ProjectContracts.
/// @dev    Deployed by PlatformFactory via deployCommunity().
///         See contracts/BUILD.md — Step 5 for full implementation notes.
contract CommunityRegistry is ICommunityRegistry {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    // ─── State ────────────────────────────────────────────────────────────────

    string public communityName;
    string public communityType;
    address public platformFactory;
    IPlatformNFTRegistry public nftRegistry;

    CouncilConfig internal _councilConfig;
    GovernanceParams internal _governanceParams;

    address[] internal _projectIndex;
    address[] internal _memberList;

    mapping(address => bool) public memberActive;
    mapping(address => MemberRole) public memberRole;
    mapping(address => bool) public pendingMembership;

    /// @dev Nonce for council multisig replay protection
    uint256 public councilNonce;

    bool public paused;

    // ─── Constructor ──────────────────────────────────────────────────────────

    constructor(
        string memory name,
        string memory cType,
        address factory,
        address nftReg,
        CouncilConfig memory councilConfig,
        GovernanceParams memory govParams
    ) {
        communityName = name;
        communityType = cType;
        platformFactory = factory;
        nftRegistry = IPlatformNFTRegistry(nftReg);
        _councilConfig = councilConfig;
        _governanceParams = govParams;

        // Register council members as members
        for (uint256 i = 0; i < councilConfig.signers.length; i++) {
            _addMember(councilConfig.signers[i], MemberRole.COUNCIL);
        }
    }

    // ─── Modifiers ────────────────────────────────────────────────────────────

    modifier onlyFactory() {
        require(msg.sender == platformFactory, "Only factory");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Paused");
        _;
    }

    // ─── Membership ───────────────────────────────────────────────────────────

    /// @notice Submit membership application.
    /// @dev    TODO: Implement full verification mode logic per BUILD.md Step 5.
    ///         For ZK_KYC_REQUIRED: check nftRegistry.isVerified(tokenId) on-chain.
    ///         For other modes: set pendingMembership[msg.sender] = true; council approves off-chain.
    function applyForMembership(bytes calldata /* proofData */) external whenNotPaused {
        require(!memberActive[msg.sender], "Already a member");
        require(!pendingMembership[msg.sender], "Application pending");

        if (_governanceParams.verificationMode == MembershipVerificationMode.ZK_KYC_REQUIRED) {
            uint256 tokenId = nftRegistry.getTokenId(msg.sender);
            require(tokenId != 0, "Must have platform NFT");
            require(nftRegistry.isVerified(tokenId), "KYC verification required");
        }

        pendingMembership[msg.sender] = true;
        // TODO: For OPEN mode, auto-approve. For others, emit event and wait for council.
        // emit MemberApplicationReceived(msg.sender);
    }

    /// @notice Council approves a pending membership application.
    /// @dev    TODO: Verify council multisig signatures before approving.
    ///         See BUILD.md Step 5 for multisig verification pattern.
    function approveMember(address user, bytes[] calldata councilSignatures) external {
        require(pendingMembership[user], "No pending application");
        _verifyCouncilSignatures(
            keccak256(abi.encodePacked("approveMember", user, councilNonce++)),
            councilSignatures
        );
        pendingMembership[user] = false;
        _addMember(user, MemberRole.MEMBER);
    }

    /// @notice Council removes a member.
    function removeMember(address user, bytes[] calldata councilSignatures) external {
        require(memberActive[user], "Not an active member");
        _verifyCouncilSignatures(
            keccak256(abi.encodePacked("removeMember", user, councilNonce++)),
            councilSignatures
        );
        memberActive[user] = false;
        uint256 tokenId = nftRegistry.getTokenId(user);
        if (tokenId != 0) {
            nftRegistry.removeCommunityMembership(tokenId, address(this));
        }
        emit MemberRemoved(user);
    }

    // ─── Project Deployment ───────────────────────────────────────────────────

    /// @notice Deploy a new child ProjectContract for an approved proposal.
    /// @dev    TODO: Import ProjectContract, deploy with constructor args, register
    ///         with NFT registry, add to _projectIndex. See BUILD.md Step 5.
    function deployProject(
        string calldata ipfsProposalHash,
        MilestoneDefinition[] calldata milestones,
        address escrowToken,
        VisibilityMode visibility,
        address[] calldata targetCommunities
    ) external returns (address projectContract) {
        // TODO: Verify council signatures for project deployment
        // TODO: Deploy ProjectContract
        // TODO: nftRegistry.registerProjectContract(projectContract)
        // TODO: _projectIndex.push(projectContract)
        // TODO: emit ProjectDeployed(projectContract, keccak256(bytes(ipfsProposalHash)))
        revert("Not implemented - see BUILD.md Step 5");
    }

    // ─── Governance ───────────────────────────────────────────────────────────

    /// @notice Council updates governance parameters.
    function updateGovernanceParams(GovernanceParams calldata params, bytes[] calldata councilSignatures) external {
        _verifyCouncilSignatures(
            keccak256(abi.encodePacked("updateGovernance", councilNonce++)),
            councilSignatures
        );
        _governanceParams = params;
        emit GovernanceUpdated(params);
    }

    // ─── Internal ─────────────────────────────────────────────────────────────

    function _addMember(address user, MemberRole role) internal {
        memberActive[user] = true;
        memberRole[user] = role;
        _memberList.push(user);

        uint256 tokenId = nftRegistry.getTokenId(user);
        if (tokenId != 0) {
            nftRegistry.addCommunityMembership(tokenId, address(this), role);
        }
        emit MemberRegistered(user, role);
    }

    /// @notice Verify that enough council members signed the given message hash.
    /// @dev    TODO: Implement ECDSA multi-sig verification.
    ///         Hash the message, recover signers, verify they are in _councilConfig.signers,
    ///         check count >= _councilConfig.threshold, check no duplicates.
    function _verifyCouncilSignatures(bytes32 messageHash, bytes[] calldata signatures) internal view {
        require(signatures.length >= _councilConfig.threshold, "Insufficient signatures");
        bytes32 ethHash = messageHash.toEthSignedMessageHash();
        address[] memory recovered = new address[](signatures.length);
        uint8 validCount = 0;
        for (uint256 i = 0; i < signatures.length; i++) {
            address signer = ethHash.recover(signatures[i]);
            // Check signer is a council member and not duplicate
            for (uint256 j = 0; j < _councilConfig.signers.length; j++) {
                if (_councilConfig.signers[j] == signer) {
                    bool duplicate = false;
                    for (uint256 k = 0; k < validCount; k++) {
                        if (recovered[k] == signer) { duplicate = true; break; }
                    }
                    if (!duplicate) { recovered[validCount++] = signer; break; }
                }
            }
        }
        require(validCount >= _councilConfig.threshold, "Not enough valid council signatures");
    }

    // ─── Views ────────────────────────────────────────────────────────────────

    function isMember(address user) external view returns (bool) { return memberActive[user]; }
    function getMemberRole(address user) external view returns (MemberRole) { return memberRole[user]; }
    function getProjectIndex() external view returns (address[] memory) { return _projectIndex; }
    function getGovernanceParams() external view returns (GovernanceParams memory) { return _governanceParams; }
    function getCouncilConfig() external view returns (CouncilConfig memory) { return _councilConfig; }
    function getMemberCount() external view returns (uint256) { return _memberList.length; }
}
