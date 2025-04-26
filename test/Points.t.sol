// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Points.sol";

/**
 * @title Points Test
 * @dev Test contract for Points contract. This test suite covers token minting,
 *      access control, and other ERC20 token functionality.
 */
contract PointsTest is Test {
    Points public points;
    address public owner;
    address public eventsContract;
    address public user1;
    address public user2;

    uint256 public constant MINT_AMOUNT = 100;

    function setUp() public {
        owner = address(this);
        eventsContract = vm.addr(1);
        user1 = vm.addr(2);
        user2 = vm.addr(3);

        points = new Points();
        points.setEventsContract(eventsContract);
    }

    function testInitialSetup() public {
        assertEq(points.owner(), owner, "Owner should be set correctly");
        assertEq(points.eventsContract(), eventsContract, "Events contract should be set correctly");
        assertEq(points.name(), "Points", "Token name should be 'Points'");
        assertEq(points.symbol(), "PTS", "Token symbol should be 'PTS'");
        assertEq(points.decimals(), 18, "Decimals should be 18");
    }

    function testMintFromOwner() public {
        points.mint(user1, MINT_AMOUNT);
        assertEq(points.balanceOf(user1), MINT_AMOUNT, "User should have minted tokens");
    }

    function testMintFromEventsContract() public {
        vm.startPrank(eventsContract);
        points.mint(user1, MINT_AMOUNT);
        vm.stopPrank();

        assertEq(points.balanceOf(user1), MINT_AMOUNT, "User should have minted tokens");
    }

    function testCannotMintFromUnauthorized() public {
        vm.startPrank(user1);
        vm.expectRevert("Points: caller is not owner or events contract");
        points.mint(user2, MINT_AMOUNT);
        vm.stopPrank();
    }

    function testTransfer() public {
        points.mint(user1, MINT_AMOUNT);

        vm.startPrank(user1);
        points.transfer(user2, MINT_AMOUNT / 2);
        vm.stopPrank();

        assertEq(points.balanceOf(user1), MINT_AMOUNT / 2, "Sender should have half the tokens");
        assertEq(points.balanceOf(user2), MINT_AMOUNT / 2, "Receiver should have half the tokens");
    }

    function testApproveAndTransferFrom() public {
        points.mint(user1, MINT_AMOUNT);

        vm.startPrank(user1);
        points.approve(user2, MINT_AMOUNT);
        vm.stopPrank();

        assertEq(points.allowance(user1, user2), MINT_AMOUNT, "Allowance should be set");

        vm.startPrank(user2);
        points.transferFrom(user1, user2, MINT_AMOUNT / 2);
        vm.stopPrank();

        assertEq(points.balanceOf(user1), MINT_AMOUNT / 2, "Sender should have half the tokens");
        assertEq(points.balanceOf(user2), MINT_AMOUNT / 2, "Receiver should have half the tokens");
        assertEq(points.allowance(user1, user2), MINT_AMOUNT / 2, "Allowance should be reduced");
    }

    function testSetEventsContract() public {
        address newEventsContract = vm.addr(10);
        points.setEventsContract(newEventsContract);
        assertEq(points.eventsContract(), newEventsContract, "Events contract should be updated");
    }

    function testCannotSetEventsContractFromUnauthorized() public {
        address newEventsContract = vm.addr(10);

        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("OwnableUnauthorizedAccount(address)")), user1));
        points.setEventsContract(newEventsContract);
        vm.stopPrank();
    }

    function testOwnershipTransfer() public {
        points.transferOwnership(user1);

        vm.startPrank(user1);
        vm.stopPrank();

        assertEq(points.owner(), user1, "Ownership should be transferred to user1");
    }
}
