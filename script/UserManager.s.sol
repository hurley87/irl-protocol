// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/UserManager.sol";

/**
 * @title DeployScript
 * @notice This script deploys the UserManager contract. Simulate running it by entering
 *         `forge script script/UserManager.s.sol --sender <the_caller_address>
 *         --fork-url $GOERLI_RPC_URL -vvvv` in the terminal. To run it for
 *         real, change it to `forge script script/UserManager.s.sol
 *         --fork-url $GOERLI_RPC_URL --broadcast`.
 */
contract UserManagerScript is Script {
    function run() public {
        vm.broadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));

        UserManager userManager = new UserManager();

        console.log("UserManager deployed at:", address(userManager));
    }
}
