// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "../../src/PlatformFactory.sol";
import "../../src/PlatformNFTRegistry.sol";
import "../../src/interfaces/IDataTypes.sol";

contract PlatformNFTRegistryTest is Test, IDataTypes {
    PlatformFactory internal factory;
    PlatformNFTRegistry internal nftRegistry;

    address internal deployer = makeAddr("deployer");
    address internal mediationKey = makeAddr("mediationKey");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal community = makeAddr("community");
    address internal project = makeAddr("project");
    address internal bounty = makeAddr("bounty");
    address internal kycOracle = makeAddr("kycOracle");

    function setUp() public {
        vm.startPrank(deployer);
        factory = new PlatformFactory(mediationKey);
        nftRegistry = new PlatformNFTRegistry(address(factory));
        factory.setNFTRegistry(address(nftRegistry));
        nftRegistry.setKYCOracle(kycOracle);
        vm.stopPrank();
    }

    function test_MintRejectsInvalidAndDuplicateHandles() public {
        vm.prank(deployer);
        vm.expectRevert("Invalid handle");
        factory.mintPlatformNFT(alice, "alice handle");

        vm.startPrank(deployer);
        factory.mintPlatformNFT(alice, "alice_handle");
        vm.expectRevert("Handle already taken");
        factory.mintPlatformNFT(bob, "alice_handle");
        vm.stopPrank();
    }

    function test_RegisteredCommunityCanAddAndRemoveMembership() public {
        uint256 tokenId = _mintAlice();

        vm.prank(deployer);
        nftRegistry.registerCommunity(community);

        vm.prank(community);
        nftRegistry.addCommunityMembership(tokenId, community, MemberRole.COUNCIL);

        assertTrue(nftRegistry.isMember(tokenId, community));
        assertEq(nftRegistry.getMemberships(tokenId).length, 1);
        assertEq(nftRegistry.getCommunityCount(tokenId), 1);
        assertEq(uint256(nftRegistry.memberRoles(tokenId, community)), uint256(MemberRole.COUNCIL));

        vm.prank(community);
        nftRegistry.removeCommunityMembership(tokenId, community);

        assertFalse(nftRegistry.isMember(tokenId, community));
        assertEq(nftRegistry.getMemberships(tokenId).length, 0);
        assertEq(nftRegistry.getCommunityCount(tokenId), 0);
    }

    function test_UnregisteredCommunityCannotAddMembership() public {
        uint256 tokenId = _mintAlice();

        vm.prank(community);
        vm.expectRevert("Only registered community");
        nftRegistry.addCommunityMembership(tokenId, community, MemberRole.MEMBER);
    }

    function test_RegisteredProjectAndBountyContractsCanUpdateReputation() public {
        uint256 tokenId = _mintAlice();

        vm.startPrank(deployer);
        nftRegistry.registerProjectContract(project);
        nftRegistry.registerBountyContract(bounty);
        vm.stopPrank();

        vm.prank(project);
        nftRegistry.updateReputation(
            tokenId,
            ReputationUpdate({
                projectCompleted: true,
                projectDisputed: false,
                projectAwarded: true,
                completionVoteScore: 80
            })
        );

        assertEq(nftRegistry.projectsCompleted(tokenId), 1);
        assertEq(nftRegistry.projectsAwarded(tokenId), 1);
        assertEq(nftRegistry.getReputationScore(tokenId), 8_000);

        vm.prank(bounty);
        nftRegistry.updateReputation(
            tokenId,
            ReputationUpdate({
                projectCompleted: true,
                projectDisputed: true,
                projectAwarded: false,
                completionVoteScore: 100
            })
        );

        assertEq(nftRegistry.projectsCompleted(tokenId), 2);
        assertEq(nftRegistry.disputeCount(tokenId), 1);
        assertEq(nftRegistry.getReputationScore(tokenId), 9_000);
    }

    function test_UnregisteredContractCannotUpdateReputation() public {
        uint256 tokenId = _mintAlice();

        vm.prank(project);
        vm.expectRevert("Only registered reputation contract");
        nftRegistry.updateReputation(
            tokenId,
            ReputationUpdate({
                projectCompleted: true,
                projectDisputed: false,
                projectAwarded: false,
                completionVoteScore: 75
            })
        );
    }

    function test_TokenURIReturnsBase64MetadataPayload() public {
        uint256 tokenId = _mintAlice();

        vm.prank(kycOracle);
        nftRegistry.setKYCHash(tokenId, keccak256("alice-kyc"));

        vm.prank(deployer);
        nftRegistry.registerCommunity(community);

        vm.prank(community);
        nftRegistry.addCommunityMembership(tokenId, community, MemberRole.MEMBER);

        string memory uri = nftRegistry.tokenURI(tokenId);
        assertTrue(_startsWith(uri, "data:application/json;base64,"));

        string memory encodedJson = _slice(uri, 29, bytes(uri).length);
        string memory decodedJson = string(Base64.decode(encodedJson));

        assertTrue(_contains(decodedJson, '"Handle","value":"alice_handle"'));
        assertTrue(_contains(decodedJson, '"KYC Verified","value":"Yes"'));
        assertTrue(_contains(decodedJson, '"Community Count","display_type":"number","value":1'));
        assertTrue(_contains(decodedJson, '"external_url":"https://api.theworkingapp.io/v1/nft/1/metadata"'));
    }

    function _mintAlice() internal returns (uint256 tokenId) {
        vm.prank(deployer);
        tokenId = factory.mintPlatformNFT(alice, "alice_handle");
    }

    function _startsWith(string memory value, string memory prefix) internal pure returns (bool) {
        bytes memory valueBytes = bytes(value);
        bytes memory prefixBytes = bytes(prefix);
        if (prefixBytes.length > valueBytes.length) return false;

        for (uint256 i = 0; i < prefixBytes.length; i++) {
            if (valueBytes[i] != prefixBytes[i]) return false;
        }
        return true;
    }

    function _contains(string memory haystack, string memory needle) internal pure returns (bool) {
        bytes memory haystackBytes = bytes(haystack);
        bytes memory needleBytes = bytes(needle);
        if (needleBytes.length == 0 || needleBytes.length > haystackBytes.length) return false;

        for (uint256 i = 0; i <= haystackBytes.length - needleBytes.length; i++) {
            bool matchFound = true;
            for (uint256 j = 0; j < needleBytes.length; j++) {
                if (haystackBytes[i + j] != needleBytes[j]) {
                    matchFound = false;
                    break;
                }
            }
            if (matchFound) return true;
        }
        return false;
    }

    function _slice(string memory value, uint256 start, uint256 end) internal pure returns (string memory) {
        bytes memory valueBytes = bytes(value);
        bytes memory result = new bytes(end - start);

        for (uint256 i = start; i < end; i++) {
            result[i - start] = valueBytes[i];
        }

        return string(result);
    }
}
