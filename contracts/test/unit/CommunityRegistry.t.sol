// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "../../src/PlatformFactory.sol";
import "../../src/PlatformNFTRegistry.sol";
import "../../src/CommunityRegistry.sol";
import "../../src/ProjectContract.sol";

contract CommunityRegistryTest is Test, IDataTypes {
    using MessageHashUtils for bytes32;

    PlatformFactory internal factory;
    PlatformNFTRegistry internal nftRegistry;
    CommunityRegistry internal community;

    address internal deployer = makeAddr("deployer");
    address internal escrowToken = makeAddr("usdc");
    address internal mediationKey = makeAddr("mediationKey");
    address internal applicant = makeAddr("applicant");
    address internal targetCommunity = makeAddr("target-community");

    uint256 internal councilPk1 = uint256(keccak256("council-1"));
    uint256 internal councilPk2 = uint256(keccak256("council-2"));
    address internal council1;
    address internal council2;

    function setUp() public {
        council1 = vm.addr(councilPk1);
        council2 = vm.addr(councilPk2);

        vm.startPrank(deployer);
        factory = new PlatformFactory(mediationKey);
        nftRegistry = new PlatformNFTRegistry(address(factory));
        factory.setNFTRegistry(address(nftRegistry));
        factory.setMediationKey(mediationKey);
        factory.mintPlatformNFT(council1, "council_one");
        factory.mintPlatformNFT(council2, "council_two");
        factory.mintPlatformNFT(applicant, "applicant_one");
        vm.stopPrank();

        community = _deployCommunity(MembershipVerificationMode.OPEN);
    }

    function test_OpenMembershipApplicationApprovalAndRemoval() public {
        vm.prank(applicant);
        community.applyForMembership(hex"");
        assertTrue(community.pendingMembership(applicant));

        community.approveMember(applicant, _signApproveMember(applicant, community.councilNonce()));

        uint256 applicantTokenId = nftRegistry.getTokenId(applicant);

        assertFalse(community.pendingMembership(applicant));
        assertTrue(community.memberActive(applicant));
        assertEq(uint256(community.getMemberRole(applicant)), uint256(MemberRole.MEMBER));
        assertEq(community.getMemberCount(), 3);
        assertTrue(nftRegistry.isMember(applicantTokenId, address(community)));

        community.removeMember(applicant, _signRemoveMember(applicant, community.councilNonce()));

        assertFalse(community.memberActive(applicant));
        assertEq(community.getMemberCount(), 2);
        assertFalse(nftRegistry.isMember(applicantTokenId, address(community)));
    }

    function test_ZkKycModeRequiresVerifiedNftBeforeApplying() public {
        CommunityRegistry kycCommunity = _deployCommunity(MembershipVerificationMode.ZK_KYC_REQUIRED);
        uint256 applicantTokenId = nftRegistry.getTokenId(applicant);

        vm.prank(applicant);
        vm.expectRevert("KYC verification required");
        kycCommunity.applyForMembership(hex"");

        vm.prank(deployer);
        nftRegistry.setKYCOracle(deployer);
        vm.prank(deployer);
        nftRegistry.setKYCHash(applicantTokenId, keccak256("applicant-kyc"));

        vm.prank(applicant);
        kycCommunity.applyForMembership(hex"");

        assertTrue(kycCommunity.pendingMembership(applicant));
    }

    function test_UpdateGovernanceParamsWithCouncilMultisig() public {
        GovernanceParams memory updated = GovernanceParams({
            proposalApprovalThreshold: 7_500,
            proposalVotingWindow: 5 days,
            completionVoteWindow: 9 days,
            bidWindow: 11 days,
            councilReviewWindow: 12 days,
            tier1Threshold: 2_000e6,
            tier2Threshold: 20_000e6,
            minMembers: 3,
            portionGrantMaxPercent: 25,
            verificationMode: MembershipVerificationMode.DOCUMENT_REVIEW
        });

        community.updateGovernanceParams(updated, _signGovernanceUpdate(updated, community.councilNonce()));

        GovernanceParams memory stored = community.getGovernanceParams();
        assertEq(stored.proposalApprovalThreshold, 7_500);
        assertEq(stored.minMembers, 3);
        assertEq(stored.portionGrantMaxPercent, 25);
        assertEq(uint256(stored.verificationMode), uint256(MembershipVerificationMode.DOCUMENT_REVIEW));
    }

    function test_DeployProjectCreatesProjectAndRegistersReputationContract() public {
        address[] memory targetCommunities = new address[](1);
        targetCommunities[0] = targetCommunity;

        MilestoneDefinition[] memory milestones = _projectMilestones();
        uint256 nonce = community.councilNonce();

        address projectAddress = community.deployProject(
            "ipfs://proposal",
            milestones,
            escrowToken,
            VisibilityMode.DUAL_PUBLICITY,
            targetCommunities,
            _signDeployProject("ipfs://proposal", milestones, escrowToken, VisibilityMode.DUAL_PUBLICITY, targetCommunities, nonce)
        );

        ProjectContract project = ProjectContract(projectAddress);
        address[] memory projects = community.getProjectIndex();

        assertEq(projects.length, 1);
        assertEq(projects[0], projectAddress);
        assertTrue(nftRegistry.registeredReputationContracts(projectAddress));
        assertEq(project.communityRegistry(), address(community));
        assertEq(project.platformFactory(), address(factory));
        assertEq(address(project.nftRegistry()), address(nftRegistry));
        assertEq(project.escrowToken(), escrowToken);
        assertEq(uint256(project.visibility()), uint256(VisibilityMode.DUAL_PUBLICITY));
        assertEq(project.councilThreshold(), 2);
        assertEq(uint256(project.getState()), uint256(ProjectState.PROPOSED));
    }

    function _deployCommunity(MembershipVerificationMode mode) internal returns (CommunityRegistry deployedCommunity) {
        CouncilConfig memory config = _councilConfig();
        GovernanceParams memory params = _governanceParams(mode);

        vm.prank(deployer);
        deployedCommunity = CommunityRegistry(factory.deployCommunity("Builders Guild", config, params));
    }

    function _councilConfig() internal view returns (CouncilConfig memory config) {
        address[] memory signers = new address[](2);
        signers[0] = council1;
        signers[1] = council2;
        config = CouncilConfig({ signers: signers, threshold: 2 });
    }

    function _governanceParams(MembershipVerificationMode mode) internal pure returns (GovernanceParams memory params) {
        params = GovernanceParams({
            proposalApprovalThreshold: 6_000,
            proposalVotingWindow: 7 days,
            completionVoteWindow: 10 days,
            bidWindow: 14 days,
            councilReviewWindow: 14 days,
            tier1Threshold: 1_000e6,
            tier2Threshold: 10_000e6,
            minMembers: 2,
            portionGrantMaxPercent: 30,
            verificationMode: mode
        });
    }

    function _projectMilestones() internal pure returns (MilestoneDefinition[] memory definitions) {
        definitions = new MilestoneDefinition[](2);
        definitions[0] = MilestoneDefinition({
            name: "Mobilisation",
            description: "Start work",
            value: 300e6,
            expectedCompletionTs: 7 days,
            verificationType: MilestoneVerificationType.COUNCIL_ONLY,
            state: MilestoneState.PENDING,
            ipfsEvidence: "",
            signaturesReceived: 0,
            signaturesRequired: 1,
            rejectionCount: 0
        });
        definitions[1] = MilestoneDefinition({
            name: "Delivery",
            description: "Finish work",
            value: 700e6,
            expectedCompletionTs: 21 days,
            verificationType: MilestoneVerificationType.FULL_COMMUNITY_VOTE,
            state: MilestoneState.PENDING,
            ipfsEvidence: "",
            signaturesReceived: 0,
            signaturesRequired: 1,
            rejectionCount: 0
        });
    }

    function _signApproveMember(address user, uint256 nonce) internal returns (bytes[] memory signatures) {
        bytes32 digest = keccak256(abi.encode("approveMember", user, nonce));
        return _signDigest(digest);
    }

    function _signRemoveMember(address user, uint256 nonce) internal returns (bytes[] memory signatures) {
        bytes32 digest = keccak256(abi.encode("removeMember", user, nonce));
        return _signDigest(digest);
    }

    function _signGovernanceUpdate(
        GovernanceParams memory params,
        uint256 nonce
    ) internal returns (bytes[] memory signatures) {
        bytes32 digest = keccak256(abi.encode("updateGovernance", params, nonce));
        return _signDigest(digest);
    }

    function _signDeployProject(
        string memory ipfsProposalHash,
        MilestoneDefinition[] memory milestones,
        address token,
        VisibilityMode visibility,
        address[] memory targetCommunities,
        uint256 nonce
    ) internal returns (bytes[] memory signatures) {
        bytes32 digest = keccak256(
            abi.encode(
                "deployProject",
                ipfsProposalHash,
                milestones,
                token,
                visibility,
                targetCommunities,
                nonce
            )
        );
        return _signDigest(digest);
    }

    function _signDigest(bytes32 digest) internal returns (bytes[] memory signatures) {
        bytes32 ethSignedDigest = digest.toEthSignedMessageHash();
        signatures = new bytes[](2);
        signatures[0] = _signatureFor(councilPk1, ethSignedDigest);
        signatures[1] = _signatureFor(councilPk2, ethSignedDigest);
    }

    function _signatureFor(uint256 privateKey, bytes32 digest) internal returns (bytes memory signature) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        signature = abi.encodePacked(r, s, v);
    }
}
