// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin-contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin-contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";

contract StubsUpgradable is Initializable, ERC1155Upgradeable, Ownable2StepUpgradeable, UUPSUpgradeable {
    address public eventsContract;
    mapping(uint256 => string) private _tokenURIs;

    modifier onlyOwnerOrEvents() {
        require(_msgSender() == owner() || _msgSender() == eventsContract, "Caller is not owner or events contract");
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(string memory baseUri) public initializer {
        __ERC1155_init(baseUri);
        __Ownable2Step_init();
        __Context_init();
        _transferOwnership(_msgSender());
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function setEventsContract(address _eventsContract) external onlyOwner {
        eventsContract = _eventsContract;
    }

    function setURI(string memory newuri) external onlyOwner {
        _setURI(newuri);
    }

    /**
     * @dev Sets the URI for a specific token ID
     * @param tokenId The token ID to set the URI for
     * @param tokenURI The URI to set for the token
     */
    function setTokenURI(uint256 tokenId, string memory tokenURI) external onlyOwnerOrEvents {
        _tokenURIs[tokenId] = tokenURI;
        emit URI(tokenURI, tokenId);
    }

    /**
     * @dev Returns the URI for a given token ID
     * @param tokenId The token ID to query
     * @return The URI for the token ID
     */
    function uri(uint256 tokenId) public view override returns (string memory) {
        string memory tokenURI = _tokenURIs[tokenId];

        // If there's a token-specific URI, return it
        if (bytes(tokenURI).length > 0) {
            return tokenURI;
        }

        // Otherwise, return the base URI
        return super.uri(tokenId);
    }

    function mint(address account, uint256 id, uint256 amount) external onlyOwnerOrEvents {
        _mint(account, id, amount, "");
    }

    function burn(address account, uint256 id, uint256 amount) external onlyOwner {
        _burn(account, id, amount);
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}
