// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/EventsUpgradable.sol";
import "../src/StubsUpgradable.sol";
import "../src/PointsUpgradable.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title DeployScript
 * @notice This script deploys Events, Points, and Stubs using the UUPS proxy pattern. Simulate running it by entering
 *         `forge script script/Deploy.s.sol --sender <the_caller_address>
 *         --fork-url $GOERLI_RPC_URL -vvvv` in the terminal. To run it for
 *         real, change it to `forge script script/Deploy.s.sol
 *         --fork-url $GOERLI_RPC_URL --broadcast`.
 */
contract DeployScript is Script {
    function run() public {
        vm.broadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));

        // Deploy Points implementation and proxy
        PointsUpgradable pointsImpl = new PointsUpgradable();
        bytes memory pointsInitData = abi.encodeWithSelector(PointsUpgradable.initialize.selector);
        ERC1967Proxy pointsProxy = new ERC1967Proxy(address(pointsImpl), pointsInitData);
        PointsUpgradable points = PointsUpgradable(address(pointsProxy));

        // Deploy Stubs implementation and proxy
        StubsUpgradable stubsImpl = new StubsUpgradable();
        bytes memory stubsInitData = abi.encodeWithSelector(StubsUpgradable.initialize.selector, "");
        ERC1967Proxy stubsProxy = new ERC1967Proxy(address(stubsImpl), stubsInitData);
        StubsUpgradable stubs = StubsUpgradable(address(stubsProxy));

        // Deploy Events implementation and proxy
        EventsUpgradable eventsImpl = new EventsUpgradable();
        bytes memory eventsInitData =
            abi.encodeWithSelector(EventsUpgradable.initialize.selector, address(stubs), address(points));
        ERC1967Proxy eventsProxy = new ERC1967Proxy(address(eventsImpl), eventsInitData);
        EventsUpgradable events = EventsUpgradable(address(eventsProxy));

        // Transfer ownership of Points and Stubs to Events contract
        points.transferOwnership(address(events));
        stubs.transferOwnership(address(events));

        // Accept ownership transfers
        vm.startPrank(address(events));
        points.acceptOwnership();
        stubs.acceptOwnership();

        // Set Events contract in Stubs
        stubs.setEventsContract(address(events));
        vm.stopPrank();

        console.log("Stubs implementation deployed at:", address(stubsImpl));
        console.log("Stubs proxy deployed at:", address(stubs));
        console.log("Points implementation deployed at:", address(pointsImpl));
        console.log("Points proxy deployed at:", address(points));
        console.log("Events implementation deployed at:", address(eventsImpl));
        console.log("Events proxy deployed at:", address(events));
    }
}
