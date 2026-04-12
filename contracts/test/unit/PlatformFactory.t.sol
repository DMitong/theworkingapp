// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/PlatformFactory.sol";
import "../../src/PlatformNFTRegistry.sol";
import "../../src/CommunityRegistry.sol";
import "../../src/BountyContract.sol";

contract PlatformFactoryTest is Test, IDataTypes {
    PlatformFactory internal factory;
    PlatformNFTRegistry internal nftRegistry;

    address internal deployer = makeAddr("deployer");
    address internal founder = makeAddr("founder");
    address internal mediationKey = makeAddr("mediationKey");
    address internal escrowToken = makeAddr("usdc");

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
        factory.mintPlatformNFT(council1, "council_one");
        factory.mintPlatformNFT(council2, "council_two");
        vm.stopPrank();
    }

    function test_DeployCommunityRegistersFactoryAndNftRegistryState() public {
        vm.prank(founder);
        address communityAddress = factory.deployCommunity("Builders Guild", _councilConfig(), _governanceParams());

        CommunityRegistry community = CommunityRegistry(communityAddress);

        assertEq(factory.getCommunityCount(), 1);
        assertTrue(factory.isCommunity(communityAddress));
        assertTrue(nftRegistry.registeredCommunities(communityAddress));
        assertEq(community.communityName(), "Builders Guild");
        assertEq(community.communityType(), "GENERAL");
        assertEq(community.platformFactory(), address(factory));
        assertEq(address(community.nftRegistry()), address(nftRegistry));
        assertEq(community.getMemberCount(), 2);
        assertEq(uint256(community.getMemberRole(council1)), uint256(MemberRole.COUNCIL));
        assertEq(uint256(community.getMemberRole(council2)), uint256(MemberRole.COUNCIL));
        assertTrue(nftRegistry.isMember(nftRegistry.getTokenId(council1), communityAddress));
        assertTrue(nftRegistry.isMember(nftRegistry.getTokenId(council2), communityAddress));
    }

    function test_DeployBountyRegistersTrackingAndMetadata() public {
        vm.prank(founder);
        address bountyAddress = factory.deployBounty(
            "ipfs://bounty",
            _milestones(),
            escrowToken,
            VisibilityMode.PLATFORM_PUBLIC,
            new address[](0)
        );

        BountyContract bounty = BountyContract(bountyAddress);

        assertEq(factory.getBountyCount(), 1);
        assertTrue(factory.isBountyContract(bountyAddress));
        assertTrue(nftRegistry.registeredReputationContracts(bountyAddress));
        assertEq(bounty.creator(), founder);
        assertEq(bounty.platformFactory(), address(factory));
        assertEq(bounty.mediationKey(), mediationKey);
        assertEq(uint256(bounty.getState()), uint256(ProjectState.TENDERING));
        assertEq(bounty.totalEscrowRequired(), 1_000e6);
    }

    function test_PauseBlocksNewDeployments() public {
        vm.prank(deployer);
        factory.pause();

        vm.prank(founder);
        vm.expectRevert();
        factory.deployCommunity("Builders Guild", _councilConfig(), _governanceParams());

        vm.prank(founder);
        vm.expectRevert();
        factory.deployBounty(
            "ipfs://bounty",
            _milestones(),
            escrowToken,
            VisibilityMode.PLATFORM_PUBLIC,
            new address[](0)
        );
    }

    function test_RejectsInvalidCouncilConfiguration() public {
        CouncilConfig memory invalidConfig = CouncilConfig({
            signers: new address[](1),
            threshold: 2
        });
        invalidConfig.signers[0] = council1;

        vm.prank(founder);
        vm.expectRevert("Threshold exceeds signers");
        factory.deployCommunity("Broken Council", invalidConfig, _governanceParams());
    }

    function _councilConfig() internal view returns (CouncilConfig memory config) {
        address[] memory signers = new address[](2);
        signers[0] = council1;
        signers[1] = council2;
        config = CouncilConfig({ signers: signers, threshold: 2 });
    }

    function _governanceParams() internal pure returns (GovernanceParams memory params) {
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
            verificationMode: MembershipVerificationMode.OPEN
        });
    }

    function _milestones() internal pure returns (MilestoneDefinition[] memory definitions) {
        definitions = new MilestoneDefinition[](2);
        definitions[0] = MilestoneDefinition({
            name: "Phase 1",
            description: "Kickoff",
            value: 400e6,
            expectedCompletionTs: 7 days,
            verificationType: MilestoneVerificationType.COUNCIL_ONLY,
            state: MilestoneState.PENDING,
            ipfsEvidence: "",
            signaturesReceived: 0,
            signaturesRequired: 1,
            rejectionCount: 0
        });
        definitions[1] = MilestoneDefinition({
            name: "Phase 2",
            description: "Complete",
            value: 600e6,
            expectedCompletionTs: 21 days,
            verificationType: MilestoneVerificationType.FULL_COMMUNITY_VOTE,
            state: MilestoneState.PENDING,
            ipfsEvidence: "",
            signaturesReceived: 0,
            signaturesRequired: 1,
            rejectionCount: 0
        });
    }
}
