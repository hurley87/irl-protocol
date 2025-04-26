// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin-contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin-contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin-contracts-upgradeable/utils/ContextUpgradeable.sol";

contract PointsUpgradable is Initializable, ERC20Upgradeable, Ownable2StepUpgradeable, UUPSUpgradeable {
    address public eventsContract;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __UUPSUpgradeable_init();
        __ERC20_init("Points", "PTS");
        __Ownable2Step_init();
        _transferOwnership(_msgSender());
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function setEventsContract(address _eventsContract) external onlyOwner {
        eventsContract = _eventsContract;
    }

    function mint(address to, uint256 amount) external {
        require(
            _msgSender() == owner() || _msgSender() == eventsContract, "Points: caller is not owner or events contract"
        );
        _mint(to, amount);
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}
