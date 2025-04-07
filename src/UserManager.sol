// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "openzeppelin-contracts/access/Ownable.sol";

/// @title UserManager Contract
/// @notice Manages user profiles and their associated addresses
/// @dev Handles user creation, name management, and address tracking
contract UserManager is Ownable {
    /// @notice Structure containing user profile information
    /// @param userId Unique identifier for the user
    /// @param username Display name of the user
    /// @param primaryAddress Index of the primary address in the addresses array
    /// @param addresses Array of addresses associated with the user
    struct UserInfo {
        uint256 userId;
        string username;
        uint256 primaryAddress;
        address[] addresses;
    }

    mapping(uint256 => UserInfo) public userIdMapping;
    mapping(string => uint256) public usernameToId;
    mapping(address => uint256) public addressToId;

    // Counter for generating unique user IDs
    uint256 private _userIdCounter;

    // Constants for username validation
    uint256 private constant MIN_USERNAME_LENGTH = 3;
    uint256 private constant MAX_USERNAME_LENGTH = 10;

    event UserCreated(uint256 indexed userId, string username, address primaryAddress);
    event UsernameUpdated(uint256 indexed userId, string oldUsername, string newUsername);
    event AddressAdded(uint256 indexed userId, address newAddress);
    event PrimaryAddressUpdated(uint256 indexed userId, address oldPrimary, address newPrimary);

    constructor() Ownable() {
        _userIdCounter = 1; // Start user IDs from 1
    }

    /// @notice Validates a username according to ENS-like rules
    /// @param name The username to validate
    /// @return bool Whether the username is valid
    function _isValidUsername(string memory name) internal pure returns (bool) {
        bytes memory b = bytes(name);
        if (b.length < MIN_USERNAME_LENGTH || b.length > MAX_USERNAME_LENGTH) return false;

        // Cannot start or end with hyphen
        if (b[0] == "-" || b[b.length - 1] == "-") return false;

        // Check each character
        for (uint256 i = 0; i < b.length; i++) {
            bytes1 char = b[i];

            // Check for consecutive hyphens
            if (char == "-" && i > 0 && b[i - 1] == "-") return false;

            // Check if character is valid
            if (
                !(char >= 0x61 && char <= 0x7A) // a-z
                    && !(char >= 0x30 && char <= 0x39) // 0-9
                    && !(char == 0x2D)
            ) {
                // hyphen
                return false;
            }
        }

        return true;
    }

    /// @notice Creates a new user with the given name and primary address
    /// @param name The username for the new user
    /// @return uint256 The newly created user's ID
    function createUser(string memory name) external returns (uint256) {
        require(_isValidUsername(name), "Invalid username format");
        require(usernameToId[name] == 0, "Username already taken");
        require(addressToId[msg.sender] == 0, "Address already registered");

        uint256 newUserId = _userIdCounter++;
        address[] memory initialAddresses = new address[](1);
        initialAddresses[0] = msg.sender;

        UserInfo memory newUser =
            UserInfo({userId: newUserId, username: name, primaryAddress: 0, addresses: initialAddresses});

        userIdMapping[newUserId] = newUser;
        usernameToId[name] = newUserId;
        addressToId[msg.sender] = newUserId;

        emit UserCreated(newUserId, name, msg.sender);
        return newUserId;
    }

    /// @notice Gets the username for a given user ID
    /// @param userId The ID of the user to query
    /// @return string memory The username of the user
    function getName(uint256 userId) external view returns (string memory) {
        require(userIdMapping[userId].userId != 0, "User does not exist");
        return userIdMapping[userId].username;
    }

    /// @notice Updates the username for a given user ID
    /// @param userId The ID of the user to update
    /// @param name The new username
    function setName(uint256 userId, string memory name) external {
        require(userIdMapping[userId].userId != 0, "User does not exist");
        require(_isValidUsername(name), "Invalid username format");
        require(usernameToId[name] == 0, "Username already taken");

        // Only allow the user's primary address to update the name
        UserInfo storage user = userIdMapping[userId];
        require(msg.sender == user.addresses[user.primaryAddress], "Only primary address can update username");

        string memory oldUsername = user.username;
        delete usernameToId[oldUsername];

        user.username = name;
        usernameToId[name] = userId;

        emit UsernameUpdated(userId, oldUsername, name);
    }

    /// @notice Adds a new address to a user's profile
    /// @param userId The ID of the user to update
    /// @param newAddress The new address to add
    function addAddress(uint256 userId, address newAddress) external {
        require(userIdMapping[userId].userId != 0, "User does not exist");
        require(addressToId[newAddress] == 0, "Address already registered");

        // Only allow the user's primary address to add new addresses
        UserInfo storage user = userIdMapping[userId];
        require(msg.sender == user.addresses[user.primaryAddress], "Only primary address can add new addresses");

        user.addresses.push(newAddress);
        addressToId[newAddress] = userId;

        emit AddressAdded(userId, newAddress);
    }

    /// @notice Updates the primary address for a user
    /// @param userId The ID of the user to update
    /// @param newPrimaryIndex The index of the new primary address in the addresses array
    function updatePrimaryAddress(uint256 userId, uint256 newPrimaryIndex) external {
        require(userIdMapping[userId].userId != 0, "User does not exist");

        UserInfo storage user = userIdMapping[userId];
        require(newPrimaryIndex < user.addresses.length, "Invalid address index");
        require(
            msg.sender == user.addresses[user.primaryAddress], "Only current primary address can update primary address"
        );

        address oldPrimary = user.addresses[user.primaryAddress];
        user.primaryAddress = newPrimaryIndex;

        emit PrimaryAddressUpdated(userId, oldPrimary, user.addresses[newPrimaryIndex]);
    }

    /// @notice Gets the primary address for a user
    /// @param userId The ID of the user to query
    /// @return address The primary address of the user
    function getPrimaryAddress(uint256 userId) external view returns (address) {
        require(userIdMapping[userId].userId != 0, "User does not exist");
        return userIdMapping[userId].addresses[userIdMapping[userId].primaryAddress];
    }

    /// @notice Gets all addresses associated with a user
    /// @param userId The ID of the user to query
    /// @return address[] memory Array of addresses associated with the user
    function getUserAddresses(uint256 userId) external view returns (address[] memory) {
        require(userIdMapping[userId].userId != 0, "User does not exist");
        return userIdMapping[userId].addresses;
    }
}
