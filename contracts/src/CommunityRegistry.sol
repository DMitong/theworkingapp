// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "./interfaces/ICommunityRegistry.sol";
import "./interfaces/IPlatformNFTRegistry.sol";
import "./ProjectContract.sol";

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
    mapping(address => uint256) internal _memberIndexPlusOne;

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
    function applyForMembership(bytes calldata proofData) external whenNotPaused {
        require(!memberActive[msg.sender], "Already a member");
        require(!pendingMembership[msg.sender], "Application pending");

        if (_governanceParams.verificationMode == MembershipVerificationMode.ZK_KYC_REQUIRED) {
            uint256 tokenId = nftRegistry.getTokenId(msg.sender);
            require(tokenId != 0, "Must have platform NFT");
            require(nftRegistry.isVerified(tokenId), "KYC verification required");
        } else if (_governanceParams.verificationMode != MembershipVerificationMode.OPEN) {
            require(proofData.length > 0, "Proof required");
        }

        pendingMembership[msg.sender] = true;
    }

    /// @notice Council approves a pending membership application.
    /// @dev    TODO: Verify council multisig signatures before approving.
    ///         See BUILD.md Step 5 for multisig verification pattern.
    function approveMember(address user, bytes[] calldata councilSignatures) external whenNotPaused {
        require(pendingMembership[user], "No pending application");
        _verifyCouncilSignatures(
            _hashApproveMember(user, councilNonce),
            councilSignatures
        );
        councilNonce++;

        if (_governanceParams.verificationMode == MembershipVerificationMode.ZK_KYC_REQUIRED) {
            uint256 tokenId = nftRegistry.getTokenId(user);
            require(tokenId != 0, "Must have platform NFT");
            require(nftRegistry.isVerified(tokenId), "KYC verification required");
        }

        pendingMembership[user] = false;
        _addMember(user, MemberRole.MEMBER);
        emit MemberApproved(user);
    }

    /// @notice Council removes a member.
    function removeMember(address user, bytes[] calldata councilSignatures) external whenNotPaused {
        require(memberActive[user], "Not an active member");
        _verifyCouncilSignatures(
            _hashRemoveMember(user, councilNonce),
            councilSignatures
        );
        councilNonce++;
        _removeMember(user);
    }

    function deployProject(
        string calldata ipfsProposalHash,
        MilestoneDefinition[] calldata milestones,
        address escrowToken,
        VisibilityMode visibility,
        address[] calldata targetCommunities,
        bytes[] calldata councilSignatures
    ) external whenNotPaused returns (address projectContract) {
        require(bytes(ipfsProposalHash).length > 0, "Invalid proposal hash");
        require(escrowToken != address(0), "Invalid escrow token");
        require(milestones.length > 0, "No milestones");

        _verifyCouncilSignatures(
            _hashDeployProject(ipfsProposalHash, milestones, escrowToken, visibility, targetCommunities, councilNonce),
            councilSignatures
        );
        councilNonce++;
        projectContract = _deployProjectInternal(ipfsProposalHash, escrowToken, visibility, targetCommunities);
    }

    /// @notice Council updates governance parameters.
    function updateGovernanceParams(GovernanceParams calldata params, bytes[] calldata councilSignatures) external whenNotPaused {
        _verifyCouncilSignatures(
            _hashGovernanceUpdate(params, councilNonce),
            councilSignatures
        );
        councilNonce++;
        _governanceParams = params;
        emit GovernanceUpdated(params);
    }

    function setPaused(bool value) external onlyFactory {
        paused = value;
    }

    // ─── Internal ─────────────────────────────────────────────────────────────

    function _addMember(address user, MemberRole role) internal {
        require(!memberActive[user], "Already active");
        memberActive[user] = true;
        memberRole[user] = role;
        _memberList.push(user);
        _memberIndexPlusOne[user] = _memberList.length;

        uint256 tokenId = nftRegistry.getTokenId(user);
        if (tokenId != 0) {
            nftRegistry.addCommunityMembership(tokenId, address(this), role);
        }
        emit MemberRegistered(user, role);
    }

    function _removeMember(address user) internal {
        memberActive[user] = false;
        delete memberRole[user];

        uint256 memberIndex = _memberIndexPlusOne[user];
        if (memberIndex != 0) {
            uint256 index = memberIndex - 1;
            uint256 lastIndex = _memberList.length - 1;

            if (index != lastIndex) {
                address lastMember = _memberList[lastIndex];
                _memberList[index] = lastMember;
                _memberIndexPlusOne[lastMember] = memberIndex;
            }

            _memberList.pop();
            delete _memberIndexPlusOne[user];
        }

        uint256 tokenId = nftRegistry.getTokenId(user);
        if (tokenId != 0) {
            nftRegistry.removeCommunityMembership(tokenId, address(this));
        }

        emit MemberRemoved(user);
    }

    function _deployProjectInternal(
        string calldata ipfsProposalHash,
        address escrowToken,
        VisibilityMode visibility,
        address[] calldata targetCommunities
    ) internal returns (address projectContract) {
        ProjectContract project = new ProjectContract(
            address(this),
            platformFactory,
            _mediationKey(),
            address(nftRegistry),
            ipfsProposalHash,
            escrowToken,
            visibility,
            _copyAddressArray(targetCommunities),
            _governanceParams,
            _copyCouncilSigners(),
            _councilConfig.threshold
        );

        projectContract = address(project);
        nftRegistry.registerProjectContract(projectContract);
        _projectIndex.push(projectContract);
        emit ProjectDeployed(projectContract, keccak256(bytes(ipfsProposalHash)));
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

    function _hashApproveMember(address user, uint256 nonce) internal pure returns (bytes32) {
        return keccak256(abi.encode("approveMember", user, nonce));
    }

    function _hashRemoveMember(address user, uint256 nonce) internal pure returns (bytes32) {
        return keccak256(abi.encode("removeMember", user, nonce));
    }

    function _hashGovernanceUpdate(GovernanceParams calldata params, uint256 nonce) internal pure returns (bytes32) {
        return keccak256(abi.encode("updateGovernance", params, nonce));
    }

    function _hashDeployProject(
        string calldata ipfsProposalHash,
        MilestoneDefinition[] calldata milestones,
        address escrowToken,
        VisibilityMode visibility,
        address[] calldata targetCommunities,
        uint256 nonce
    ) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                "deployProject",
                ipfsProposalHash,
                milestones,
                escrowToken,
                visibility,
                targetCommunities,
                nonce
            )
        );
    }

    function _copyCouncilSigners() internal view returns (address[] memory signers) {
        signers = new address[](_councilConfig.signers.length);
        for (uint256 i = 0; i < _councilConfig.signers.length; i++) {
            signers[i] = _councilConfig.signers[i];
        }
    }

    function _copyAddressArray(address[] calldata input) internal pure returns (address[] memory output) {
        output = new address[](input.length);
        for (uint256 i = 0; i < input.length; i++) {
            output[i] = input[i];
        }
    }

    function _mediationKey() internal view returns (address key) {
        (bool success, bytes memory data) = platformFactory.staticcall(
            abi.encodeWithSignature("mediationKey()")
        );
        require(success && data.length != 0, "Factory mediation key unavailable");
        key = abi.decode(data, (address));
    }

    // ─── Views ────────────────────────────────────────────────────────────────

    function isMember(address user) external view returns (bool) { return memberActive[user]; }
    function getMemberRole(address user) external view returns (MemberRole) { return memberRole[user]; }
    function getProjectIndex() external view returns (address[] memory) { return _projectIndex; }
    function getGovernanceParams() external view returns (GovernanceParams memory) { return _governanceParams; }
    function getCouncilConfig() external view returns (CouncilConfig memory) { return _councilConfig; }
    function getMemberCount() external view returns (uint256) { return _memberList.length; }
}
