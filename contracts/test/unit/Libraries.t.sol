// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../../src/interfaces/IDataTypes.sol";
import "../../src/libraries/Escrow.sol";
import "../../src/libraries/Voting.sol";
import "../../src/libraries/MilestoneManager.sol";

contract MockUSDC is ERC20 {
    constructor() ERC20("Mock USDC", "mUSDC") {}

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract LibraryHarness is IDataTypes {
    using Escrow for Escrow.Ledger;
    using Voting for Voting.Tally;
    using MilestoneManager for MilestoneDefinition[];

    Escrow.Ledger private _ledger;
    Voting.Tally private _tally;
    mapping(address => uint8) private _votes;
    MilestoneDefinition[] private _milestones;
    mapping(uint8 => mapping(address => bool)) private _milestoneSignatures;
    uint8 private _currentMilestoneIndex;

    function initializeMilestones(MilestoneDefinition[] calldata definitions) external returns (uint256 totalValue) {
        totalValue = _milestones.initializeMilestones(definitions);
        _ledger.initializeMilestoneBalances(_milestones);
    }

    function deposit(address token, uint256 amount) external {
        _ledger.deposit(amount, token);
    }

    function releaseMilestone(uint8 milestoneIndex, address recipient, uint256 amount, address token) external {
        _ledger.releaseMilestone(milestoneIndex, recipient, amount, token);
    }

    function freezeEscrow() external {
        _ledger.freeze();
    }

    function unfreezeEscrow() external {
        _ledger.unfreeze();
    }

    function refundAll(address funder, address token) external returns (uint256 amount) {
        return _ledger.refundAll(funder, token);
    }

    function remainingEscrowBalance() external view returns (uint256) {
        return _ledger.remainingBalance();
    }

    function milestoneEscrowBalance(uint8 milestoneIndex) external view returns (uint256) {
        return _ledger.getMilestoneBalance(milestoneIndex);
    }

    function castVote(uint8 choice) external {
        Voting.castVote(_votes, _tally, msg.sender, choice);
    }

    function hasVoted(address voter) external view returns (bool) {
        return Voting.hasVoted(_votes, voter);
    }

    function getVoteCount(uint8 choice) external view returns (uint256) {
        return _tally.getVoteCount(choice);
    }

    function getVoteCounts(uint8[] calldata choices) external view returns (uint256[] memory) {
        return _tally.getVoteCounts(choices);
    }

    function getVoteResult(
        uint256 totalEligible,
        uint256 thresholdBps,
        uint8 approveChoice,
        uint8 rejectChoice,
        uint8 disputeChoice
    ) external view returns (VoteOutcome) {
        return _tally.getResult(totalEligible, thresholdBps, approveChoice, rejectChoice, disputeChoice);
    }

    function claimMilestone(uint8 milestoneIndex, string calldata ipfsEvidence) external {
        _milestones.claimMilestone(_currentMilestoneIndex, milestoneIndex, ipfsEvidence);
    }

    function signMilestone(uint8 milestoneIndex) external returns (uint8 signaturesReceived) {
        return _milestones.signMilestone(_milestoneSignatures, milestoneIndex, msg.sender);
    }

    function completeMilestone(uint8 milestoneIndex) external returns (bool allPaid) {
        allPaid = _milestones.completeMilestone(milestoneIndex);
        _currentMilestoneIndex = milestoneIndex + 1;
    }

    function rejectMilestone(uint8 milestoneIndex) external returns (uint8 rejectionCount) {
        return _milestones.rejectMilestone(milestoneIndex);
    }

    function currentMilestoneIndex() external view returns (uint8) {
        return _currentMilestoneIndex;
    }

    function getMilestone(uint256 milestoneIndex) external view returns (MilestoneDefinition memory) {
        return _milestones[milestoneIndex];
    }

    function getRemainingMilestoneEscrow() external view returns (uint256) {
        return _milestones.getRemainingEscrow(_currentMilestoneIndex);
    }

    function allMilestonesPaid() external view returns (bool) {
        return _milestones.isAllMilestonesPaid();
    }
}

contract LibrariesTest is Test, IDataTypes {
    MockUSDC internal usdc;
    LibraryHarness internal harness;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    function setUp() public {
        usdc = new MockUSDC();
        harness = new LibraryHarness();
    }

    function test_EscrowTracksBalancesAcrossDepositReleaseAndRefund() public {
        harness.initializeMilestones(_buildMilestones());

        usdc.mint(address(this), 1_000e6);
        usdc.approve(address(harness), 1_000e6);

        harness.deposit(address(usdc), 1_000e6);

        assertEq(harness.remainingEscrowBalance(), 1_000e6);
        assertEq(harness.milestoneEscrowBalance(0), 600e6);

        harness.releaseMilestone(0, alice, 250e6, address(usdc));

        assertEq(usdc.balanceOf(alice), 250e6);
        assertEq(harness.milestoneEscrowBalance(0), 350e6);
        assertEq(harness.remainingEscrowBalance(), 750e6);

        harness.freezeEscrow();
        vm.expectRevert(Escrow.EscrowFrozen.selector);
        harness.refundAll(bob, address(usdc));

        harness.unfreezeEscrow();
        uint256 refunded = harness.refundAll(bob, address(usdc));

        assertEq(refunded, 750e6);
        assertEq(usdc.balanceOf(bob), 750e6);
        assertEq(harness.remainingEscrowBalance(), 0);
    }

    function test_VotingTracksChoicesAndThresholdOutcomes() public {
        harness.castVote(1);

        vm.prank(alice);
        harness.castVote(1);

        vm.prank(bob);
        harness.castVote(2);

        assertTrue(harness.hasVoted(address(this)));
        assertEq(harness.getVoteCount(1), 2);
        assertEq(harness.getVoteCount(2), 1);

        uint8[] memory requestedChoices = new uint8[](3);
        requestedChoices[0] = 1;
        requestedChoices[1] = 2;
        requestedChoices[2] = 3;
        uint256[] memory counts = harness.getVoteCounts(requestedChoices);

        assertEq(counts[0], 2);
        assertEq(counts[1], 1);
        assertEq(counts[2], 0);
        assertEq(uint256(harness.getVoteResult(3, 6_000, 1, 2, 3)), uint256(VoteOutcome.APPROVED));

        vm.expectRevert(Voting.AlreadyVoted.selector);
        harness.castVote(1);
    }

    function test_MilestoneManagerEnforcesSequentialClaimsAndStateTransitions() public {
        harness.initializeMilestones(_buildMilestones());

        harness.claimMilestone(0, "ipfs://milestone-0");
        MilestoneDefinition memory firstMilestone = harness.getMilestone(0);
        assertEq(uint256(firstMilestone.state), uint256(MilestoneState.UNDER_REVIEW));
        assertEq(firstMilestone.ipfsEvidence, "ipfs://milestone-0");

        vm.expectRevert(abi.encodeWithSelector(MilestoneManager.OutOfOrderMilestone.selector, 0, 1));
        harness.claimMilestone(1, "ipfs://out-of-order");

        vm.prank(alice);
        uint8 firstSignatureCount = harness.signMilestone(0);
        assertEq(firstSignatureCount, 1);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(MilestoneManager.DuplicateSignature.selector, alice));
        harness.signMilestone(0);

        bool allPaidAfterFirst = harness.completeMilestone(0);
        assertFalse(allPaidAfterFirst);
        assertEq(harness.currentMilestoneIndex(), 1);

        harness.claimMilestone(1, "ipfs://milestone-1");
        uint8 rejectionCount = harness.rejectMilestone(1);
        assertEq(rejectionCount, 1);
        assertEq(uint256(harness.getMilestone(1).state), uint256(MilestoneState.REJECTED));

        harness.claimMilestone(1, "ipfs://milestone-1-retry");
        bool allPaidAfterSecond = harness.completeMilestone(1);

        assertTrue(allPaidAfterSecond);
        assertTrue(harness.allMilestonesPaid());
        assertEq(harness.getRemainingMilestoneEscrow(), 0);
    }

    function _buildMilestones() internal pure returns (MilestoneDefinition[] memory definitions) {
        definitions = new MilestoneDefinition[](2);
        definitions[0] = MilestoneDefinition({
            name: "Mobilisation",
            description: "Kickoff and site prep",
            value: 600e6,
            expectedCompletionTs: 1 days,
            verificationType: MilestoneVerificationType.COUNCIL_ONLY,
            state: MilestoneState.PENDING,
            ipfsEvidence: "",
            signaturesReceived: 0,
            signaturesRequired: 2,
            rejectionCount: 0
        });
        definitions[1] = MilestoneDefinition({
            name: "Completion",
            description: "Final delivery",
            value: 400e6,
            expectedCompletionTs: 2 days,
            verificationType: MilestoneVerificationType.FULL_COMMUNITY_VOTE,
            state: MilestoneState.PENDING,
            ipfsEvidence: "",
            signaturesReceived: 0,
            signaturesRequired: 1,
            rejectionCount: 0
        });
    }
}
