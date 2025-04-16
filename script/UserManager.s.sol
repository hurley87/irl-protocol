// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/UserManager.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title DeployScript
 * @notice This script deploys the UserManager contract using the UUPS proxy pattern. Simulate running it by entering
 *         `forge script script/UserManager.s.sol --sender <the_caller_address>
 *         --fork-url $GOERLI_RPC_URL -vvvv` in the terminal. To run it for
 *         real, change it to `forge script script/UserManager.s.sol
 *         --fork-url $GOERLI_RPC_URL --broadcast`.
 */ 
contract UserManagerScript is Script {
    function run() public {
        vm.broadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));

        // Deploy UserManager implementation and proxy
        UserManager userManagerImpl = new UserManager();
        bytes memory userManagerInitData = abi.encodeWithSelector(UserManager.initialize.selector);
        ERC1967Proxy userManagerProxy = new ERC1967Proxy(address(userManagerImpl), userManagerInitData);
        UserManager userManager = UserManager(address(userManagerProxy));

        console.log("UserManager implementation deployed at:", address(userManagerImpl));
        console.log("UserManager proxy deployed at:", address(userManager));
    }
}
