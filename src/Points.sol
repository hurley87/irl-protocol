// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Points is ERC20, Ownable {
    address public eventsContract;

    constructor() ERC20("Points", "PTS") Ownable(msg.sender) {}

    function setEventsContract(address _eventsContract) external onlyOwner {
        eventsContract = _eventsContract;
    }

    function mint(address to, uint256 amount) external {
        require(
            _msgSender() == owner() || _msgSender() == eventsContract, "Points: caller is not owner or events contract"
        );
        _mint(to, amount);
    }
}
