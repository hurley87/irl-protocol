// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin-contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin-contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";

contract Stubs is Initializable, ERC1155Upgradeable, Ownable2StepUpgradeable, UUPSUpgradeable {
    address public eventsContract;

    modifier onlyOwnerOrEvents() {
        require(msg.sender == owner() || msg.sender == eventsContract, "Caller is not owner or events contract");
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(string memory uri) public initializer {
        __Ownable2Step_init();
        __ERC1155_init(uri);
        __UUPSUpgradeable_init();
        _transferOwnership(msg.sender);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

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

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}
