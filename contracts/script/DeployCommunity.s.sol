// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/PlatformFactory.sol";
import "../src/CommunityRegistry.sol";
import "../src/interfaces/IDataTypes.sol";

/// @notice Deploys a sample CommunityRegistry via the PlatformFactory.
///         Reads the factory address from deployments/{chainId}.json.
///         Run with: forge script script/DeployCommunity.s.sol --rpc-url <RPC> --broadcast
contract DeployCommunity is Script, IDataTypes {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        // Read factory address from deployment artifact
        string memory deploymentPath = string(abi.encodePacked("deployments/", vm.toString(block.chainid), ".json"));
        string memory json = vm.readFile(deploymentPath);
        address factoryAddr = vm.parseJsonAddress(json, ".PlatformFactory");

        console.log("Deploying Community via PlatformFactory");
        console.log("Deployer:", deployer);
        console.log("Factory: ", factoryAddr);
        console.log("Chain ID:", block.chainid);

        PlatformFactory factory = PlatformFactory(factoryAddr);

        // Configure council — read from env or use defaults
        address councilSigner1 = vm.envOr("COUNCIL_SIGNER_1", deployer);
        address councilSigner2 = vm.envOr("COUNCIL_SIGNER_2", deployer);
        uint8 threshold = uint8(vm.envOr("COUNCIL_THRESHOLD", uint256(1)));
        string memory communityName = vm.envOr("COMMUNITY_NAME", string("Test Community"));

        address[] memory signers = new address[](2);
        signers[0] = councilSigner1;
        signers[1] = councilSigner2;

        CouncilConfig memory config = CouncilConfig({
            signers: signers,
            threshold: threshold
        });

        GovernanceParams memory params = GovernanceParams({
            proposalApprovalThreshold: 6_000,  // 60%
            proposalVotingWindow: 7 days,
            completionVoteWindow: 10 days,
            bidWindow: 14 days,
            councilReviewWindow: 14 days,
            tier1Threshold: 1_000e6,            // 1,000 USDC
            tier2Threshold: 10_000e6,           // 10,000 USDC
            minMembers: 2,
            portionGrantMaxPercent: 30,
            verificationMode: MembershipVerificationMode.OPEN
        });

        vm.startBroadcast(deployerKey);

        address communityAddr = factory.deployCommunity(communityName, config, params);
        console.log("CommunityRegistry deployed at:", communityAddr);

        vm.stopBroadcast();

        // Append to deployment JSON
        string memory updatedJson = string(
            abi.encodePacked(
                '{"chainId":', vm.toString(block.chainid),
                ',"PlatformFactory":"', vm.toString(factoryAddr),
                '","LatestCommunity":"', vm.toString(communityAddr),
                '"}'
            )
        );
        string memory communityPath = string(
            abi.encodePacked("deployments/community-", vm.toString(block.chainid), ".json")
        );
        vm.writeFile(communityPath, updatedJson);
        console.log("Community address written to", communityPath);
    }
}
