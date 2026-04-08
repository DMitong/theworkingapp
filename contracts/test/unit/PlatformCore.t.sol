// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/PlatformFactory.sol";
import "../../src/PlatformNFTRegistry.sol";

/// @notice Tests for PlatformFactory and PlatformNFTRegistry.
///         Run with: forge test --match-contract PlatformCoreTest -vvv
contract PlatformCoreTest is Test {
    PlatformFactory factory;
    PlatformNFTRegistry nftRegistry;

    address deployer = makeAddr("deployer");
    address mediationKey = makeAddr("mediationKey");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address kycOracle = makeAddr("kycOracle");

    function setUp() public {
        vm.startPrank(deployer);
        factory = new PlatformFactory(mediationKey);
        nftRegistry = new PlatformNFTRegistry(address(factory));
        factory.setNFTRegistry(address(nftRegistry));
        nftRegistry.setKYCOracle(kycOracle);
        vm.stopPrank();
    }

    // ─── Factory tests ────────────────────────────────────────────────────────

    function test_FactoryOwner() public view {
        assertEq(factory.owner(), deployer);
    }

    function test_FactoryMediationKey() public view {
        assertEq(factory.mediationKey(), mediationKey);
    }

    function test_FactorySetNFTRegistry() public view {
        assertEq(address(factory.nftRegistry()), address(nftRegistry));
    }

    function test_FactoryPauseUnpause() public {
        vm.prank(deployer);
        factory.pause();
        assertTrue(factory.paused());

        vm.prank(deployer);
        factory.unpause();
        assertFalse(factory.paused());
    }

    function test_RevertOnNonOwnerPause() public {
        vm.prank(alice);
        vm.expectRevert();
        factory.pause();
    }

    // ─── NFT Registry tests ───────────────────────────────────────────────────

    function test_MintNFT() public {
        vm.prank(deployer); // factory owner acts as factory relay in tests
        uint256 tokenId = factory.mintPlatformNFT(alice, "alice_handle");
        assertEq(tokenId, 1);
        assertEq(nftRegistry.walletToTokenId(alice), 1);
        assertEq(nftRegistry.handles(1), "alice_handle");
    }

    function test_RevertDuplicateMint() public {
        vm.startPrank(deployer);
        factory.mintPlatformNFT(alice, "alice_handle");
        vm.expectRevert("Already registered");
        factory.mintPlatformNFT(alice, "alice_handle_2");
        vm.stopPrank();
    }

    function test_Soulbound_TransferReverts() public {
        vm.prank(deployer);
        uint256 tokenId = factory.mintPlatformNFT(alice, "alice_handle");

        vm.prank(alice);
        vm.expectRevert("Soulbound: non-transferable");
        nftRegistry.transferFrom(alice, bob, tokenId);
    }

    function test_Soulbound_ApproveReverts() public {
        vm.prank(deployer);
        uint256 tokenId = factory.mintPlatformNFT(alice, "alice_handle");

        vm.prank(alice);
        vm.expectRevert("Soulbound: non-transferable");
        nftRegistry.approve(bob, tokenId);
    }

    function test_SetKYCHash() public {
        vm.prank(deployer);
        uint256 tokenId = factory.mintPlatformNFT(alice, "alice_handle");

        bytes32 kycHash = keccak256("alice_identity_proof");

        vm.prank(kycOracle);
        nftRegistry.setKYCHash(tokenId, kycHash);

        assertTrue(nftRegistry.isVerified(tokenId));
        assertEq(nftRegistry.kycHashes(tokenId), kycHash);
    }

    function test_RevertKYCFromNonOracle() public {
        vm.prank(deployer);
        uint256 tokenId = factory.mintPlatformNFT(alice, "alice_handle");

        vm.prank(alice);
        vm.expectRevert("Only KYC oracle");
        nftRegistry.setKYCHash(tokenId, keccak256("proof"));
    }

    function test_IsVerified_FalseWithoutKYC() public {
        vm.prank(deployer);
        uint256 tokenId = factory.mintPlatformNFT(alice, "alice_handle");
        assertFalse(nftRegistry.isVerified(tokenId));
    }

    function test_GetTokenId() public {
        vm.prank(deployer);
        factory.mintPlatformNFT(alice, "alice_handle");
        assertEq(nftRegistry.getTokenId(alice), 1);
        assertEq(nftRegistry.getTokenId(bob), 0); // not registered
    }

    // ─── TODO: Add tests for ─────────────────────────────────────────────────
    // - addCommunityMembership (requires a registered community)
    // - removeCommunityMembership
    // - updateReputation
    // - getMemberships
    // - reputation score calculation (weighted average)
    // - multiple NFT mints (sequential IDs)
}
