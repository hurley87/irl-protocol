// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Stubs.sol";

/**
 * @title Stubs Test
 * @dev Test contract for Stubs contract. This test suite covers core functionality
 *      including minting, URI management, and access control.
 */
contract StubsTest is Test {
    Stubs public stubs;
    address public owner;
    address public eventsContract;
    address public user1;
    address public user2;

    string public baseUri = "https://example.com/api/token/{id}.json";
    uint256 public stubId = 1;

    function setUp() public {
        owner = address(this);
        eventsContract = vm.addr(1);
        user1 = vm.addr(2);
        user2 = vm.addr(3);

        stubs = new Stubs(baseUri);
        stubs.setEventsContract(eventsContract);
    }

    function testInitialSetup() public {
        assertEq(stubs.owner(), owner, "Owner should be set correctly");
        assertEq(stubs.eventsContract(), eventsContract, "Events contract should be set correctly");
        assertEq(stubs.uri(1), baseUri, "Base URI should be set correctly");
    }

    function testMintFromEventsContract() public {
        vm.startPrank(eventsContract);
        stubs.mint(user1, stubId, 1);
        vm.stopPrank();

        assertEq(stubs.balanceOf(user1, stubId), 1, "User should have 1 stub token");
    }

    function testMintFromOwner() public {
        stubs.mint(user1, stubId, 1);
        assertEq(stubs.balanceOf(user1, stubId), 1, "User should have 1 stub token");
    }

    function testCannotMintFromUnauthorized() public {
        vm.startPrank(user1);
        vm.expectRevert("Caller is not owner or events contract");
        stubs.mint(user2, stubId, 1);
        vm.stopPrank();
    }

    function testBurn() public {
        // Mint token first
        stubs.mint(user1, stubId, 1);
        assertEq(stubs.balanceOf(user1, stubId), 1, "User should have 1 stub token before burn");

        // Burn token
        stubs.burn(user1, stubId, 1);
        assertEq(stubs.balanceOf(user1, stubId), 0, "User should have 0 stub tokens after burn");
    }

    function testCannotBurnFromUnauthorized() public {
        // Mint token first
        stubs.mint(user1, stubId, 1);

        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("OwnableUnauthorizedAccount(address)")), user1));
        stubs.burn(user1, stubId, 1);
        vm.stopPrank();
    }

    function testSetEventsContract() public {
        address newEventsContract = vm.addr(10);
        stubs.setEventsContract(newEventsContract);
        assertEq(stubs.eventsContract(), newEventsContract, "Events contract should be updated");
    }

    function testCannotSetEventsContractFromUnauthorized() public {
        address newEventsContract = vm.addr(10);

        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("OwnableUnauthorizedAccount(address)")), user1));
        stubs.setEventsContract(newEventsContract);
        vm.stopPrank();
    }

    function testSetURI() public {
        string memory newUri = "https://new-example.com/token/{id}.json";
        stubs.setURI(newUri);
        assertEq(stubs.uri(1), newUri, "URI should be updated for all tokens");
    }

    function testCannotSetURIFromUnauthorized() public {
        string memory newUri = "https://new-example.com/token/{id}.json";

        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("OwnableUnauthorizedAccount(address)")), user1));
        stubs.setURI(newUri);
        vm.stopPrank();
    }

    function testSetTokenURI() public {
        string memory tokenUri = "https://custom-token-uri.com/specific-token.json";
        stubs.setTokenURI(stubId, tokenUri);
        assertEq(stubs.uri(stubId), tokenUri, "Token-specific URI should be set correctly");
    }

    function testSetTokenURIFromEventsContract() public {
        string memory tokenUri = "https://custom-token-uri.com/from-events.json";

        vm.startPrank(eventsContract);
        stubs.setTokenURI(stubId, tokenUri);
        vm.stopPrank();

        assertEq(stubs.uri(stubId), tokenUri, "Token-specific URI should be set correctly from events contract");
    }

    function testCannotSetTokenURIFromUnauthorized() public {
        string memory tokenUri = "https://custom-token-uri.com/from-unauthorized.json";

        vm.startPrank(user1);
        vm.expectRevert("Caller is not owner or events contract");
        stubs.setTokenURI(stubId, tokenUri);
        vm.stopPrank();
    }

    function testOwnershipTransfer() public {
        stubs.transferOwnership(user1);
        vm.startPrank(user1);
        vm.stopPrank();

        assertEq(stubs.owner(), user1, "Ownership should be transferred to user1");
    }
}
