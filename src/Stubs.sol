// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "openzeppelin-contracts/token/ERC1155/ERC1155.sol";
import "openzeppelin-contracts/access/Ownable.sol";

contract Stubs is ERC1155, Ownable {
    address public eventsContract;

    modifier onlyOwnerOrEvents() {
        require(msg.sender == owner() || msg.sender == eventsContract, "Caller is not owner or events contract");
        _;
    }

    constructor(string memory uri) ERC1155(uri) Ownable() {}

    function setEventsContract(address _eventsContract) external onlyOwner {
        eventsContract = _eventsContract;
    }

    function setURI(string memory newuri) external onlyOwner {
        _setURI(newuri);
    }

    function mint(address account, uint256 id, uint256 amount) external onlyOwnerOrEvents {
        _mint(account, id, amount, "");
    }

    function burn(address account, uint256 id, uint256 amount) external onlyOwnerOrEvents {
        _burn(account, id, amount);
    }
}