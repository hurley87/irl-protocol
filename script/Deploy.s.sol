// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/Events.sol";
import "../src/Stubs.sol";
import "../src/Points.sol";

/**
 * @title DeployScript
 * @notice This script deploys Events. Simulate running it by entering
 *         `forge script script/Deploy.s.sol --sender <the_caller_address>
 *         --fork-url $GOERLI_RPC_URL -vvvv` in the terminal. To run it for
 *         real, change it to `forge script script/Deploy.s.sol
 *         --fork-url $GOERLI_RPC_URL --broadcast`.
 */
contract DeployScript is Script {
    function run() public {
        vm.broadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));
        Events events = new Events(address(0), address(0));
        console.log("Events deployed at:", address(events));
    }
}
