// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "openzeppelin-contracts/proxy/ERC1967/ERC1967Proxy.sol";

/// @title Events Proxy Contract
/// @notice Proxy contract for the Events implementation
/// @dev Uses ERC1967Proxy for UUPS upgradeability
contract EventsProxy is ERC1967Proxy {
    constructor(address implementation, bytes memory data) ERC1967Proxy(implementation, data) {}
} 