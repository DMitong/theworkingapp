// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../../src/PlatformFactory.sol";
import "../../src/PlatformNFTRegistry.sol";
import "../../src/CommunityRegistry.sol";
import "../../src/ProjectContract.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("MockToken", "MTK") {}
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract ProjectContractTest is Test, IDataTypes {
    using MessageHashUtils for bytes32;

    PlatformFactory internal factory;
    PlatformNFTRegistry internal nftRegistry;
    CommunityRegistry internal community;
    ProjectContract internal project;
    MockERC20 internal token;

    address internal deployer = makeAddr("deployer");
    address internal mediationKey = makeAddr("mediationKey");
    address internal member1 = makeAddr("member1");
    address internal member2 = makeAddr("member2");
    address internal contractor = makeAddr("contractor");

    uint256 internal councilPk1 = uint256(keccak256("council-1"));
    uint256 internal councilPk2 = uint256(keccak256("council-2"));
    address internal council1;
    address internal council2;

    function setUp() public {
        council1 = vm.addr(councilPk1);
        council2 = vm.addr(councilPk2);
        token = new MockERC20();

        vm.startPrank(deployer);
        factory = new PlatformFactory(mediationKey);
        nftRegistry = new PlatformNFTRegistry(address(factory));
        factory.setNFTRegistry(address(nftRegistry));
        factory.setMediationKey(mediationKey);
        
        factory.mintPlatformNFT(council1, "council1");
        factory.mintPlatformNFT(council2, "council2");
        factory.mintPlatformNFT(member1, "member1");
        factory.mintPlatformNFT(member2, "member2");
        factory.mintPlatformNFT(contractor, "contractor");
        vm.stopPrank();

        CouncilConfig memory config;
        address[] memory signers = new address[](2);
        signers[0] = council1;
        signers[1] = council2;
        config.signers = signers;
        config.threshold = 2;

        GovernanceParams memory params;
        params.proposalApprovalThreshold = 5_000; // 50%
        params.proposalVotingWindow = 7 days;
        params.completionVoteWindow = 7 days;
        params.verificationMode = MembershipVerificationMode.OPEN;
        params.portionGrantMaxPercent = 30;
        params.minMembers = 2;

        vm.startPrank(deployer);
        community = CommunityRegistry(factory.deployCommunity("Test", config, params));
        vm.stopPrank();

        // Add members
        vm.prank(member1);
        community.applyForMembership(hex"");
        community.approveMember(member1, _signApproveMember(member1, community.councilNonce()));

        vm.prank(member2);
        community.applyForMembership(hex"");
        community.approveMember(member2, _signApproveMember(member2, community.councilNonce()));

        // Deploy project
        MilestoneDefinition[] memory milestones = new MilestoneDefinition[](2);
        milestones[0] = MilestoneDefinition("M1", "desc", 300e6, 0, MilestoneVerificationType.COUNCIL_ONLY, MilestoneState.PENDING, "", 0, 2, 0);
        milestones[1] = MilestoneDefinition("M2", "desc", 700e6, 0, MilestoneVerificationType.COUNCIL_ONLY, MilestoneState.PENDING, "", 0, 2, 0);

        address[] memory targets = new address[](0);
        address pAddr = community.deployProject("ipfs", milestones, address(token), VisibilityMode.PLATFORM_PUBLIC, targets, _signDeployProject("ipfs", milestones, address(token), VisibilityMode.PLATFORM_PUBLIC, targets, community.councilNonce()));
        project = ProjectContract(pAddr);
    }

    function _signApproveMember(address user, uint256 nonce) internal returns (bytes[] memory) {
        return _signDigest(keccak256(abi.encode("approveMember", user, nonce)));
    }
    
    function _signDeployProject(string memory ipfs, MilestoneDefinition[] memory miles, address tkn, VisibilityMode vis, address[] memory targs, uint256 nonce) internal returns (bytes[] memory) {
        return _signDigest(keccak256(abi.encode("deployProject", ipfs, miles, tkn, vis, targs, nonce)));
    }

    function _signDigest(bytes32 digest) internal returns (bytes[] memory signatures) {
        bytes32 ethSignedDigest = digest.toEthSignedMessageHash();
        signatures = new bytes[](2);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(councilPk1, ethSignedDigest);
        signatures[0] = abi.encodePacked(r, s, v);
        (v, r, s) = vm.sign(councilPk2, ethSignedDigest);
        signatures[1] = abi.encodePacked(r, s, v);
    }

    function _signCouncilDecision(AwardDecision d, string memory r, uint256 n) internal returns (bytes[] memory) {
        return _signDigest(keccak256(abi.encode("councilDecision", d, r, n)));
    }

    function _signPublishTender(VisibilityMode v, address[] memory t, uint256 n) internal returns (bytes[] memory) {
        return _signDigest(keccak256(abi.encode("publishTender", v, t, n)));
    }

    function _signAwardContract(address c, MilestoneDefinition[] memory m, uint256 n) internal returns (bytes[] memory) {
        return _signDigest(keccak256(abi.encode("awardContract", c, m, n)));
    }
    
    function _signPortionGrant(uint256 a, uint256 n) internal returns (bytes[] memory) {
        return _signDigest(keccak256(abi.encode("approvePortionGrant", a, n)));
    }

    function test_ProjectHappyPath() public {
        assertEq(uint256(project.getState()), uint256(ProjectState.PROPOSED));

        // 1. Voting
        vm.prank(member1);
        project.castProposalVote(true);
        vm.prank(member2);
        project.castProposalVote(true);
        assertEq(uint256(project.getState()), uint256(ProjectState.COUNCIL_REVIEW));

        // 2. Council Decision
        project.councilDecision(AwardDecision.APPROVE, "Looks good", _signCouncilDecision(AwardDecision.APPROVE, "Looks good", project.councilNonce()));
        assertEq(uint256(project.getState()), uint256(ProjectState.TENDERING));

        address[] memory targets = new address[](0);
        project.publishTender(VisibilityMode.PLATFORM_PUBLIC, targets, _signPublishTender(VisibilityMode.PLATFORM_PUBLIC, targets, project.councilNonce()));

        // 3. Bidding
        vm.prank(contractor);
        project.submitBid(BidData(1000e6, "ipfsbid", 100, "meta"));

        // 4. Award
        MilestoneDefinition[] memory milestones = new MilestoneDefinition[](2);
        milestones[0] = MilestoneDefinition("M1", "desc", 300e6, 0, MilestoneVerificationType.COUNCIL_ONLY, MilestoneState.PENDING, "", 0, 2, 0);
        milestones[1] = MilestoneDefinition("M2", "desc", 700e6, 0, MilestoneVerificationType.COUNCIL_ONLY, MilestoneState.PENDING, "", 0, 2, 0);
        
        project.awardContract(contractor, milestones, _signAwardContract(contractor, milestones, project.councilNonce()));
        assertEq(uint256(project.getState()), uint256(ProjectState.AWARDED));

        vm.prank(contractor);
        project.acceptAward();

        // 5. Escrow fund
        token.mint(deployer, 1000e6);
        vm.startPrank(deployer);
        token.approve(address(project), 1000e6);
        project.fundEscrow(1000e6, address(token));
        vm.stopPrank();
        assertEq(uint256(project.getState()), uint256(ProjectState.ACTIVE));

        // 6. Claims
        vm.prank(contractor);
        project.submitMilestoneCompletion(0, "evidence");
        assertEq(uint256(project.getState()), uint256(ProjectState.MILESTONE_UNDER_REVIEW));

        vm.prank(council1); project.signMilestone(0);
        vm.prank(council2); project.signMilestone(0);
        assertEq(token.balanceOf(contractor), 300e6);

        // 7. Milestone 2
        vm.prank(contractor);
        project.submitMilestoneCompletion(1, "ev2");
        vm.prank(council1); project.signMilestone(1);
        vm.prank(council2); project.signMilestone(1);
        assertEq(token.balanceOf(contractor), 1000e6);
        assertEq(uint256(project.getState()), uint256(ProjectState.COMPLETION_VOTE));

        // 8. Final Vote
        vm.prank(member1); project.castCompletionVote(VoteChoice.COMPLETED);
        vm.prank(member2); project.castCompletionVote(VoteChoice.COMPLETED);
        assertEq(uint256(project.getState()), uint256(ProjectState.COMPLETED));
    }

    function test_PortionGrant() public {
        vm.prank(member1); project.castProposalVote(true);
        vm.prank(member2); project.castProposalVote(true);
        project.councilDecision(AwardDecision.APPROVE, "Good", _signCouncilDecision(AwardDecision.APPROVE, "Good", project.councilNonce()));
        
        vm.prank(contractor); project.submitBid(BidData(1000e6, "bid", 100, "m"));
        MilestoneDefinition[] memory ms = new MilestoneDefinition[](1);
        ms[0] = MilestoneDefinition("M", "d", 1000e6, 0, MilestoneVerificationType.COUNCIL_ONLY, MilestoneState.PENDING, "", 0, 2, 0);
        project.awardContract(contractor, ms, _signAwardContract(contractor, ms, project.councilNonce()));

        token.mint(deployer, 1000e6);
        vm.startPrank(deployer);
        token.approve(address(project), 1000e6);
        project.fundEscrow(1000e6, address(token));
        vm.stopPrank();

        vm.prank(contractor);
        project.requestPortionGrant(200e6, "need gear");
        project.approvePortionGrant(_signPortionGrant(200e6, project.councilNonce()));

        assertEq(token.balanceOf(contractor), 200e6); 
    }
}
