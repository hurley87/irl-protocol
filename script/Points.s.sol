// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/Events.sol";
import "../src/Stubs.sol";
import "../src/Points.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title DeployScript
 * @notice This script deploys Events, Points, and Stubs using the UUPS proxy pattern. Simulate running it by entering
 *         `forge script script/Deploy.s.sol --sender <the_caller_address>
 *         --fork-url $GOERLI_RPC_URL -vvvv` in the terminal. To run it for
 *         real, change it to `forge script script/Deploy.s.sol
 *         --fork-url $GOERLI_RPC_URL --broadcast`.
 */ 
contract PointsScript is Script {
    function run() public {
        vm.broadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));

        // Deploy Points implementation and proxy
        Points pointsImpl = new Points();
        bytes memory pointsInitData = abi.encodeWithSelector(Points.initialize.selector);
        ERC1967Proxy pointsProxy = new ERC1967Proxy(address(pointsImpl), pointsInitData);
        Points points = Points(address(pointsProxy));

        console.log("Points implementation deployed at:", address(pointsImpl));
        console.log("Points proxy deployed at:", address(points));
    }
}
