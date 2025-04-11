// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/Events.sol";
import "../src/Stubs.sol";
import "../src/Points.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title DeployScript
 * @notice This script deploys Events using the UUPS proxy pattern. Simulate running it by entering
 *         `forge script script/Deploy.s.sol --sender <the_caller_address>
 *         --fork-url $GOERLI_RPC_URL -vvvv` in the terminal. To run it for
 *         real, change it to `forge script script/Deploy.s.sol
 *         --fork-url $GOERLI_RPC_URL --broadcast`.
 */
contract DeployScript is Script {
    function run() public {
        vm.broadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));

        // Deploy dependencies
        Stubs stubs = new Stubs();
        Points points = new Points();

        // Deploy Events implementation
        Events eventsImpl = new Events();

        // Deploy proxy and initialize it
        bytes memory initData = abi.encodeWithSelector(Events.initialize.selector, address(stubs), address(points));
        ERC1967Proxy proxy = new ERC1967Proxy(address(eventsImpl), initData);
        Events events = Events(address(proxy));

        // Transfer ownership of Points and Stubs to Events contract
        points.transferOwnership(address(events));
        stubs.transferOwnership(address(events));

        // Set Events contract in Stubs
        vm.startPrank(address(events));
        stubs.setEventsContract(address(events));
        vm.stopPrank();

        console.log("Stubs deployed at:", address(stubs));
        console.log("Points deployed at:", address(points));
        console.log("Events implementation deployed at:", address(eventsImpl));
        console.log("Events proxy deployed at:", address(events));
    }
}
