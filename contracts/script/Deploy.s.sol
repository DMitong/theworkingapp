// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/PlatformFactory.sol";
import "../src/PlatformNFTRegistry.sol";

/// @notice Deploys the core The Working App protocol contracts.
///         Run with: forge script script/Deploy.s.sol --rpc-url <RPC> --broadcast --verify
contract Deploy is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        address mediationKey = vm.envAddress("PLATFORM_MEDIATION_KEY");

        console.log("Deploying The Working App Protocol");
        console.log("Deployer:      ", deployer);
        console.log("Mediation key: ", mediationKey);
        console.log("Chain ID:      ", block.chainid);

        vm.startBroadcast(deployerKey);

        // 1. Deploy PlatformFactory
        PlatformFactory factory = new PlatformFactory(mediationKey);
        console.log("PlatformFactory deployed at:", address(factory));

        // 2. Deploy PlatformNFTRegistry
        PlatformNFTRegistry nftRegistry = new PlatformNFTRegistry(address(factory));
        console.log("PlatformNFTRegistry deployed at:", address(nftRegistry));

        // 3. Wire them together
        factory.setNFTRegistry(address(nftRegistry));

        vm.stopBroadcast();

        // Write addresses to file for backend consumption
        string memory json = string(
            abi.encodePacked(
                '{"chainId":', vm.toString(block.chainid),
                ',"PlatformFactory":"', vm.toString(address(factory)),
                '","PlatformNFTRegistry":"', vm.toString(address(nftRegistry)),
                '"}'
            )
        );

        string memory path = string(abi.encodePacked("deployments/", vm.toString(block.chainid), ".json"));
        vm.writeFile(path, json);
        console.log("Addresses written to", path);
    }
}
