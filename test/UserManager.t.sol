// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/UserManager.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title UserManager Test
 * @dev Test contract for UserManager contract. This test suite covers all core functionality
 *      including user creation, name management, and address tracking.
 */
contract UserManagerTest is Test {
    UserManager userManager;
    address owner;
    address user1;
    address user2;
    address user3;

    event UserCreated(uint256 indexed userId, string username, address primaryAddress);
    event UsernameUpdated(uint256 indexed userId, string oldUsername, string newUsername);
    event AddressAdded(uint256 indexed userId, address newAddress);
    event PrimaryAddressUpdated(uint256 indexed userId, address oldPrimary, address newPrimary);

    // Import custom errors from OpenZeppelin v5.0.0
    error OwnableUnauthorizedAccount(address account);
    error EnforcedPause();

    function setUp() public {
        owner = address(this);
        user1 = vm.addr(1);
        user2 = vm.addr(2);
        user3 = vm.addr(3);

        // Deploy the contract
        userManager = new UserManager();

        // Log addresses
        console.log("Owner address:", owner);
        console.log("User1 address:", user1);
        console.log("User2 address:", user2);
        console.log("User3 address:", user3);
        console.log("UserManager contract:", address(userManager));
    }

    function testCreateUser() public {
        vm.startPrank(user1);
        vm.expectEmit(true, true, true, true);
        emit UserCreated(1, "user1", user1);
        uint256 userId = userManager.createUser("user1");
        vm.stopPrank();

        assertEq(userId, 1, "User ID should be 1");
        assertEq(userManager.getName(userId), "user1", "Username should match");
        assertEq(userManager.getPrimaryAddress(userId), user1, "Primary address should match");
        assertEq(userManager.usernameToId("user1"), userId, "Username to ID mapping should match");
        assertEq(userManager.addressToId(user1), userId, "Address to ID mapping should match");
    }

    function testCannotCreateUserWithInvalidUsername() public {
        vm.startPrank(user1);
        vm.expectRevert("Invalid username format");
        userManager.createUser("a"); // Too short
        vm.stopPrank();

        vm.startPrank(user1);
        vm.expectRevert("Invalid username format");
        userManager.createUser("username12345"); // Too long
        vm.stopPrank();

        vm.startPrank(user1);
        vm.expectRevert("Invalid username format");
        userManager.createUser("-user"); // Starts with hyphen
        vm.stopPrank();

        vm.startPrank(user1);
        vm.expectRevert("Invalid username format");
        userManager.createUser("user-"); // Ends with hyphen
        vm.stopPrank();

        vm.startPrank(user1);
        vm.expectRevert("Invalid username format");
        userManager.createUser("user--name"); // Consecutive hyphens
        vm.stopPrank();
    }

    function testCannotCreateUserWithTakenUsername() public {
        vm.startPrank(user1);
        userManager.createUser("user1");
        vm.stopPrank();

        vm.startPrank(user2);
        vm.expectRevert("Username already taken");
        userManager.createUser("user1");
        vm.stopPrank();
    }

    function testCannotCreateUserWithRegisteredAddress() public {
        vm.startPrank(user1);
        userManager.createUser("user1");
        vm.stopPrank();

        vm.startPrank(user1);
        vm.expectRevert("Address already registered");
        userManager.createUser("user2");
        vm.stopPrank();
    }

    function testUpdateUsername() public {
        vm.startPrank(user1);
        uint256 userId = userManager.createUser("user1");
        vm.stopPrank();

        vm.startPrank(user1);
        vm.expectEmit(true, true, true, true);
        emit UsernameUpdated(userId, "user1", "newuser");
        userManager.setName(userId, "newuser");
        vm.stopPrank();

        assertEq(userManager.getName(userId), "newuser", "Username should be updated");
        assertEq(userManager.usernameToId("newuser"), userId, "New username mapping should be set");
        assertEq(userManager.usernameToId("user1"), 0, "Old username mapping should be cleared");
    }

    function testCannotUpdateUsernameWithInvalidName() public {
        vm.startPrank(user1);
        uint256 userId = userManager.createUser("user1");
        vm.stopPrank();

        vm.startPrank(user1);
        vm.expectRevert("Invalid username format");
        userManager.setName(userId, "a"); // Too short
        vm.stopPrank();
    }

    function testCannotUpdateUsernameWithTakenName() public {
        vm.startPrank(user1);
        uint256 userId1 = userManager.createUser("user1");
        vm.stopPrank();

        vm.startPrank(user2);
        userManager.createUser("user2");
        vm.stopPrank();

        vm.startPrank(user1);
        vm.expectRevert("Username already taken");
        userManager.setName(userId1, "user2");
        vm.stopPrank();
    }

    function testCannotUpdateUsernameFromNonPrimaryAddress() public {
        vm.startPrank(user1);
        uint256 userId = userManager.createUser("user1");
        vm.stopPrank();

        vm.startPrank(user2);
        vm.expectRevert("Only primary address can update username");
        userManager.setName(userId, "newuser");
        vm.stopPrank();
    }

    function testAddAddress() public {
        vm.startPrank(user1);
        uint256 userId = userManager.createUser("user1");
        vm.stopPrank();

        vm.startPrank(user1);
        vm.expectEmit(true, true, true, true);
        emit AddressAdded(userId, user2);
        userManager.addAddress(userId, user2);
        vm.stopPrank();

        address[] memory addresses = userManager.getUserAddresses(userId);
        assertEq(addresses.length, 2, "Should have 2 addresses");
        assertEq(addresses[0], user1, "First address should be user1");
        assertEq(addresses[1], user2, "Second address should be user2");
        assertEq(userManager.addressToId(user2), userId, "New address mapping should be set");
    }

    function testCannotAddRegisteredAddress() public {
        vm.startPrank(user1);
        uint256 userId1 = userManager.createUser("user1");
        vm.stopPrank();

        vm.startPrank(user2);
        userManager.createUser("user2");
        vm.stopPrank();

        vm.startPrank(user1);
        vm.expectRevert("Address already registered");
        userManager.addAddress(userId1, user2);
        vm.stopPrank();
    }

    function testCannotAddAddressFromNonPrimaryAddress() public {
        vm.startPrank(user1);
        uint256 userId = userManager.createUser("user1");
        vm.stopPrank();

        vm.startPrank(user2);
        vm.expectRevert("Only primary address can add new addresses");
        userManager.addAddress(userId, user3);
        vm.stopPrank();
    }

    function testUpdatePrimaryAddress() public {
        vm.startPrank(user1);
        uint256 userId = userManager.createUser("user1");
        userManager.addAddress(userId, user2);
        vm.stopPrank();

        vm.startPrank(user1);
        vm.expectEmit(true, true, true, true);
        emit PrimaryAddressUpdated(userId, user1, user2);
        userManager.updatePrimaryAddress(userId, 1);
        vm.stopPrank();

        assertEq(userManager.getPrimaryAddress(userId), user2, "Primary address should be updated");
    }

    function testCannotUpdatePrimaryAddressFromNonPrimaryAddress() public {
        vm.startPrank(user1);
        uint256 userId = userManager.createUser("user1");
        userManager.addAddress(userId, user2);
        vm.stopPrank();

        vm.startPrank(user2);
        vm.expectRevert("Only current primary address can update primary address");
        userManager.updatePrimaryAddress(userId, 1);
        vm.stopPrank();
    }

    function testCannotUpdatePrimaryAddressWithInvalidIndex() public {
        vm.startPrank(user1);
        uint256 userId = userManager.createUser("user1");
        vm.stopPrank();

        vm.startPrank(user1);
        vm.expectRevert("Invalid address index");
        userManager.updatePrimaryAddress(userId, 1);
        vm.stopPrank();
    }

    function testGetUserAddresses() public {
        vm.startPrank(user1);
        uint256 userId = userManager.createUser("user1");
        userManager.addAddress(userId, user2);
        userManager.addAddress(userId, user3);
        vm.stopPrank();

        address[] memory addresses = userManager.getUserAddresses(userId);
        assertEq(addresses.length, 3, "Should have 3 addresses");
        assertEq(addresses[0], user1, "First address should be user1");
        assertEq(addresses[1], user2, "Second address should be user2");
        assertEq(addresses[2], user3, "Third address should be user3");
    }

    function testGetNonExistentUser() public {
        vm.expectRevert("User does not exist");
        userManager.getName(999);

        vm.expectRevert("User does not exist");
        userManager.getPrimaryAddress(999);

        vm.expectRevert("User does not exist");
        userManager.getUserAddresses(999);
    }

    function testPauseAndUnpause() public {
        // Pause the contract
        userManager.pause();

        // Try to create a user while paused
        vm.startPrank(user1);
        vm.expectRevert(EnforcedPause.selector);
        userManager.createUser("user1");
        vm.stopPrank();

        // Unpause the contract
        userManager.unpause();

        // Create a user after unpausing
        vm.startPrank(user1);
        uint256 userId = userManager.createUser("user1");
        vm.stopPrank();

        assertEq(userId, 1, "User ID should be 1");
    }

    function testOnlyOwnerCanPause() public {
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, user1));
        userManager.pause();
        vm.stopPrank();

        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, user1));
        userManager.unpause();
        vm.stopPrank();
    }
}
