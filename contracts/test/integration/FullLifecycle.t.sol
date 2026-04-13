// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../../src/PlatformFactory.sol";
import "../../src/PlatformNFTRegistry.sol";
import "../../src/CommunityRegistry.sol";
import "../../src/ProjectContract.sol";

contract MockUSD is ERC20 {
    constructor() ERC20("USDC", "USDC") {}
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract FullLifecycleTest is Test, IDataTypes {
    using MessageHashUtils for bytes32;

    PlatformFactory factory;
    PlatformNFTRegistry nftRegistry;
    MockUSD usdc;

    address factoryOwner = makeAddr("factoryOwner");
    address kycOracle = makeAddr("kycOracle");
    address mediationKey = makeAddr("mediationKey");

    // Community Members
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address charlie = makeAddr("charlie");
    address contractor = makeAddr("contractor");

    uint256 councilPk1 = uint256(keccak256("council-1"));
    uint256 councilPk2 = uint256(keccak256("council-2"));
    address council1;
    address council2;

    function setUp() public {
        council1 = vm.addr(councilPk1);
        council2 = vm.addr(councilPk2);
        usdc = new MockUSD();

        vm.startPrank(factoryOwner);
        factory = new PlatformFactory(mediationKey);
        nftRegistry = new PlatformNFTRegistry(address(factory));
        factory.setNFTRegistry(address(nftRegistry));
        
        // Register identities
        factory.mintPlatformNFT(council1, "council1");
        factory.mintPlatformNFT(council2, "council2");
        factory.mintPlatformNFT(alice, "alice_handle");
        factory.mintPlatformNFT(bob, "bob_handle");
        factory.mintPlatformNFT(charlie, "charlie_handle");
        factory.mintPlatformNFT(contractor, "contracting_firm");

        // Set KYC oracle
        nftRegistry.setKYCOracle(kycOracle);
        vm.stopPrank();

        // Pass KYC for everyone
        vm.startPrank(kycOracle);
        nftRegistry.setKYCHash(1, keccak256("c1"));
        nftRegistry.setKYCHash(2, keccak256("c2"));
        nftRegistry.setKYCHash(3, keccak256("al"));
        nftRegistry.setKYCHash(4, keccak256("bo"));
        nftRegistry.setKYCHash(5, keccak256("ch"));
        nftRegistry.setKYCHash(6, keccak256("co"));
        vm.stopPrank();
    }

    function _signApproveMember(address user, uint256 nonce) internal returns (bytes[] memory) {
        bytes32 digest = keccak256(abi.encode("approveMember", user, nonce));
        return _signDigest(digest);
    }
    
    function _signDeployProject(string memory ipfs, MilestoneDefinition[] memory miles, address tkn, VisibilityMode vis, address[] memory targs, uint256 nonce) internal returns (bytes[] memory) {
        bytes32 digest = keccak256(abi.encode("deployProject", ipfs, miles, tkn, vis, targs, nonce));
        return _signDigest(digest);
    }
    
    function _signCouncilDecision(AwardDecision d, string memory r, uint256 n) internal returns (bytes[] memory) {
        return _signDigest(keccak256(abi.encode("councilDecision", d, r, n)));
    }

    function _signAwardContract(address c, MilestoneDefinition[] memory m, uint256 n) internal returns (bytes[] memory) {
        return _signDigest(keccak256(abi.encode("awardContract", c, m, n)));
    }

    function _signDigest(bytes32 digest) internal returns (bytes[] memory signatures) {
        bytes32 ethSignedDigest = digest.toEthSignedMessageHash();
        signatures = new bytes[](2);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(councilPk1, ethSignedDigest);
        signatures[0] = abi.encodePacked(r, s, v);
        (v, r, s) = vm.sign(councilPk2, ethSignedDigest);
        signatures[1] = abi.encodePacked(r, s, v);
    }

    // Step-by-step E2E Lifecycle
    function test_E2E_FullPlatformLifecycle() public {
        // --- 1. DEPLOY COMMUNITY ---
        CouncilConfig memory config;
        address[] memory signers = new address[](2);
        signers[0] = council1;
        signers[1] = council2;
        config.signers = signers;
        config.threshold = 2;

        GovernanceParams memory params;
        params.proposalApprovalThreshold = 5_000;
        params.proposalVotingWindow = 7 days;
        params.completionVoteWindow = 7 days;
        params.verificationMode = MembershipVerificationMode.ZK_KYC_REQUIRED;
        params.minMembers = 2;

        vm.prank(factoryOwner);
        address commAddr = factory.deployCommunity("Pioneer Guild", config, params);
        CommunityRegistry community = CommunityRegistry(commAddr);

        // --- 2. JOIN COMMUNITY ---
        vm.prank(alice); community.applyForMembership(hex"");
        community.approveMember(alice, _signApproveMember(alice, community.councilNonce()));

        vm.prank(bob); community.applyForMembership(hex"");
        community.approveMember(bob, _signApproveMember(bob, community.councilNonce()));

        vm.prank(charlie); community.applyForMembership(hex"");
        community.approveMember(charlie, _signApproveMember(charlie, community.councilNonce()));

        assertEq(community.getMemberCount(), 5); // 3 members + 2 council

        // --- 3. PROPOSE PROJECT ---
        MilestoneDefinition[] memory milestones = new MilestoneDefinition[](1);
        milestones[0] = MilestoneDefinition("Deliver", "All out", 5000e6, 0, MilestoneVerificationType.COUNCIL_MEMBER_QUORUM, MilestoneState.PENDING, "", 0, 2, 0);

        address[] memory targets = new address[](0);
        address pAddr = community.deployProject("ipfs://new-idea", milestones, address(usdc), VisibilityMode.PLATFORM_PUBLIC, targets, _signDeployProject("ipfs://new-idea", milestones, address(usdc), VisibilityMode.PLATFORM_PUBLIC, targets, community.councilNonce()));
        ProjectContract project = ProjectContract(pAddr);

        // --- 4. GOVERNANCE ---
        vm.prank(alice); project.castProposalVote(true);
        vm.prank(bob); project.castProposalVote(true);
        vm.prank(charlie); project.castProposalVote(false);
        // Hits threshold (2/5 > 50% ? wait, 2 out of 5 is 40%. The threshold is 50%. Let's add council 1 vote)
        vm.prank(council1); project.castProposalVote(true);
        // Now 3/5 = 60% -> Tends to transition state!
        assertEq(uint256(project.getState()), uint256(ProjectState.COUNCIL_REVIEW));

        // --- 5. COUNCIL REVIEW ---
        project.councilDecision(AwardDecision.APPROVE, "Good idea", _signCouncilDecision(AwardDecision.APPROVE, "Good idea", project.councilNonce()));

        // --- 6. BIDDING & AWARDING ---
        vm.prank(contractor);
        project.submitBid(BidData(5000e6, "ipfs://bid-doc", 30, "Fast output"));

        project.awardContract(contractor, milestones, _signAwardContract(contractor, milestones, project.councilNonce()));

        // --- 7. FUNDING ESCROW ---
        usdc.mint(alice, 5000e6);
        vm.startPrank(alice);
        usdc.approve(address(project), 5000e6);
        project.fundEscrow(5000e6, address(usdc));
        vm.stopPrank();

        // --- 8. MILESTONE SUBMISSION AND REPUTATION CHECK ---
        vm.prank(contractor);
        project.submitMilestoneCompletion(0, "ipfs://evidence");

        vm.prank(council1); project.signMilestone(0);
        vm.prank(council2); project.signMilestone(0); // Paid!
        assertEq(usdc.balanceOf(contractor), 5000e6); // Funds transferred securely!

        // --- 9. PLATFORM SUCCESS METRICS ---
        vm.prank(alice); project.castCompletionVote(VoteChoice.COMPLETED);
        vm.prank(bob); project.castCompletionVote(VoteChoice.COMPLETED);
        vm.prank(council1); project.castCompletionVote(VoteChoice.COMPLETED);
        
        assertEq(uint256(project.getState()), uint256(ProjectState.COMPLETED));

        uint256 contractorIdentity = nftRegistry.getTokenId(contractor);
        assertEq(nftRegistry.projectsCompleted(contractorIdentity), 1);
        assertEq(nftRegistry.reputationScores(contractorIdentity), 10000); // Max bps!
    }
}
