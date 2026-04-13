// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../../src/PlatformFactory.sol";
import "../../src/BountyContract.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("MockToken", "MTK") {}
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract BountyContractTest is Test, IDataTypes {
    BountyContract public bounty;
    MockERC20 public token;
    
    address creator = makeAddr("creator");
    address contractor = makeAddr("contractor");
    address panelMember = makeAddr("panel");

    function setUp() public {
        token = new MockERC20();
        address[] memory panel = new address[](1);
        panel[0] = panelMember;
        address[] memory targets = new address[](0);
        
        MilestoneDefinition[] memory milestones = new MilestoneDefinition[](1);
        milestones[0] = MilestoneDefinition("Deliver", "desc", 500e6, 0, MilestoneVerificationType.COUNCIL_ONLY, MilestoneState.PENDING, "", 0, 1, 0);

        bounty = new BountyContract(creator, makeAddr("factory"), makeAddr("mediationKey"), "hash", milestones, address(token), VisibilityMode.PLATFORM_PUBLIC, targets, panel);
    }

    function test_HappyPathBounty() public {
        vm.prank(contractor);
        bounty.submitBid(BidData(500e6, "bid", 10, "meta"));
        
        vm.prank(creator);
        bounty.selectBid(contractor);

        token.mint(creator, 500e6);
        vm.startPrank(creator);
        token.approve(address(bounty), 500e6);
        bounty.fundEscrow(500e6, address(token));
        vm.stopPrank();

        vm.prank(contractor);
        bounty.submitMilestoneCompletion(0, "ev");
        
        vm.prank(panelMember);
        bounty.castPanelVote(0, true);

        assertEq(token.balanceOf(contractor), 500e6);
        assertEq(uint256(bounty.getState()), uint256(ProjectState.COMPLETED));
    }
}
