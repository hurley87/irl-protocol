// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Events.sol";
import "../src/Stubs.sol";
import "../src/Points.sol";

/**
 * @title Events Test
 * @dev Test contract for Events contract. This test suite covers all core functionality
 *      including event creation, check-ins, allowlist management, and event lifecycle.
 */
contract EventsTest is Test {
    // Event interfaces
    event EventStubContractUpdated(address indexed oldStub, address indexed newStub);
    event EventPointsContractUpdated(address indexed oldPoints, address indexed newPoints);

    Events _events;
    Stubs _stubs;
    Points _points;
    address _owner;
    address _user1;
    address _user2;
    address _user3;

    uint256 _eventId = 1;
    uint256 _stubId = 1;
    uint256 _pointsAmount = 100;
    uint256 _maxCapacity = 10;
    uint256 _startTime;
    uint256 _endTime;

    function setUp() public {
        _owner = address(this);
        _user1 = vm.addr(1);
        _user2 = vm.addr(2);
        _user3 = vm.addr(3);

        // Deploy Points, Stubs, and Events contracts
        _points = new Points();
        _stubs = new Stubs("https://example.com/api/token/{id}.json");
        _events = new Events(address(_stubs), address(_points));

        // Set up ownership and permissions
        vm.startPrank(_owner);
        _points.transferOwnership(address(_events));
        _stubs.transferOwnership(address(_events));
        vm.stopPrank();

        vm.startPrank(address(_events));
        _points.setEventsContract(address(_events));
        _stubs.setEventsContract(address(_events));
        vm.stopPrank();

        // Set up event times
        _startTime = block.timestamp + 1 days;
        _endTime = _startTime + 1 days;

        // Log addresses for debugging
        console.log("Owner address:", _owner);
        console.log("Events address:", address(_events));
        console.log("Stubs address:", address(_stubs));
        console.log("Points address:", address(_points));
    }

    function testCreateEvent() public {
        _events.createEvent(_eventId, _stubId, _pointsAmount, _startTime, _endTime, _maxCapacity);

        (
            uint256 stubId,
            uint256 points,
            uint256 startTime,
            uint256 endTime,
            uint256 maxCapacity,
            uint256 totalCheckedIn,
            bool exists
        ) = _events.getEventDetails(_eventId);

        assertEq(stubId, _stubId, "Stub ID should match");
        assertEq(points, _pointsAmount, "Points should match");
        assertEq(startTime, _startTime, "Start time should match");
        assertEq(endTime, _endTime, "End time should match");
        assertEq(maxCapacity, _maxCapacity, "Max capacity should match");
        assertEq(totalCheckedIn, 0, "Initial check-ins should be 0");
        assertTrue(exists, "Event should exist");
    }

    function testCannotCreateDuplicateEvent() public {
        _events.createEvent(_eventId, _stubId, _pointsAmount, _startTime, _endTime, _maxCapacity);

        vm.expectRevert("Event already exists");
        _events.createEvent(_eventId, _stubId, _pointsAmount, _startTime, _endTime, _maxCapacity);
    }

    function testSetAllowlist() public {
        _events.createEvent(_eventId, _stubId, _pointsAmount, _startTime, _endTime, _maxCapacity);

        address[] memory attendees = new address[](2);
        attendees[0] = _user1;
        attendees[1] = _user2;

        _events.setAllowlist(_eventId, attendees, true);

        assertTrue(_events.isUserAllowlisted(_eventId, _user1), "User1 should be allowlisted");
        assertTrue(_events.isUserAllowlisted(_eventId, _user2), "User2 should be allowlisted");
        assertFalse(_events.isUserAllowlisted(_eventId, _user3), "User3 should not be allowlisted");
    }

    function testCheckIn() public {
        _events.createEvent(_eventId, _stubId, _pointsAmount, _startTime, _endTime, _maxCapacity);

        address[] memory attendees = new address[](1);
        attendees[0] = _user1;
        _events.setAllowlist(_eventId, attendees, true);

        // Move time to event start
        vm.warp(_startTime);

        // Check in
        vm.startPrank(_user1);
        _events.checkIn(_eventId);
        vm.stopPrank();

        assertTrue(_events.isUserCheckedIn(_eventId, _user1), "User1 should be checked in");
        assertEq(_events.getEventCheckInCount(_eventId), 1, "Check-in count should be 1");
        assertEq(_points.balanceOf(_user1), _pointsAmount, "User1 should have points");
        assertEq(_stubs.balanceOf(_user1, _stubId), 1, "User1 should have stub NFT");
    }

    function testCannotCheckInTwice() public {
        _events.createEvent(_eventId, _stubId, _pointsAmount, _startTime, _endTime, _maxCapacity);

        address[] memory attendees = new address[](1);
        attendees[0] = _user1;
        _events.setAllowlist(_eventId, attendees, true);

        // Move time to event start
        vm.warp(_startTime);

        vm.startPrank(_user1);
        _events.checkIn(_eventId);

        vm.expectRevert("Already checked in");
        _events.checkIn(_eventId);
        vm.stopPrank();
    }

    function testCannotCheckInBeforeStart() public {
        _events.createEvent(_eventId, _stubId, _pointsAmount, _startTime, _endTime, _maxCapacity);

        address[] memory attendees = new address[](1);
        attendees[0] = _user1;
        _events.setAllowlist(_eventId, attendees, true);

        // Time before event start
        vm.warp(_startTime - 1);

        vm.startPrank(_user1);
        vm.expectRevert("Check-in hasn't started");
        _events.checkIn(_eventId);
        vm.stopPrank();
    }

    function testCannotCheckInAfterEnd() public {
        _events.createEvent(_eventId, _stubId, _pointsAmount, _startTime, _endTime, _maxCapacity);

        address[] memory attendees = new address[](1);
        attendees[0] = _user1;
        _events.setAllowlist(_eventId, attendees, true);

        // Time after event end
        vm.warp(_endTime + 1);

        vm.startPrank(_user1);
        vm.expectRevert("Check-in period ended");
        _events.checkIn(_eventId);
        vm.stopPrank();
    }

    function testCannotCheckInIfNotAllowlisted() public {
        _events.createEvent(_eventId, _stubId, _pointsAmount, _startTime, _endTime, _maxCapacity);

        address[] memory attendees = new address[](1);
        attendees[0] = _user1;
        _events.setAllowlist(_eventId, attendees, true);

        // Move time to event start
        vm.warp(_startTime);

        vm.startPrank(_user2);
        vm.expectRevert("Not on allowlist");
        _events.checkIn(_eventId);
        vm.stopPrank();
    }

    function testAutoEndEvent() public {
        _events.createEvent(_eventId, _stubId, _pointsAmount, _startTime, _endTime, _maxCapacity);

        address[] memory attendees = new address[](1);
        attendees[0] = _user1;
        _events.setAllowlist(_eventId, attendees, true);

        // Move time to event start
        vm.warp(_startTime);

        _events.autoEndEvent(_eventId);

        vm.startPrank(_user1);
        vm.expectRevert("Check-in period ended");
        _events.checkIn(_eventId);
        vm.stopPrank();

        (,,, bool hasEnded,) = _events.getEventStatus(_eventId);
        assertTrue(hasEnded, "Event should be marked as ended");
    }

    function testUpdateEventTimes() public {
        _events.createEvent(_eventId, _stubId, _pointsAmount, _startTime, _endTime, _maxCapacity);

        uint256 newStartTime = _startTime + 1 days;
        uint256 newEndTime = _endTime + 1 days;

        _events.updateEventTimes(_eventId, newStartTime, newEndTime);

        (,, uint256 startTime, uint256 endTime,,,) = _events.getEventDetails(_eventId);

        assertEq(startTime, newStartTime, "Start time should be updated");
        assertEq(endTime, newEndTime, "End time should be updated");
    }

    function testCannotUpdateStartedEvent() public {
        _events.createEvent(_eventId, _stubId, _pointsAmount, _startTime, _endTime, _maxCapacity);

        // Move time to event start
        vm.warp(_startTime);

        uint256 newStartTime = _startTime + 1 days;
        uint256 newEndTime = _endTime + 1 days;

        vm.expectRevert("Cannot modify started event");
        _events.updateEventTimes(_eventId, newStartTime, newEndTime);
    }

    function testUpdateEventCapacity() public {
        _events.createEvent(_eventId, _stubId, _pointsAmount, _startTime, _endTime, _maxCapacity);

        uint256 newCapacity = _maxCapacity + 5;
        _events.updateEventCapacity(_eventId, newCapacity);

        (,,,, uint256 maxCapacity,,) = _events.getEventDetails(_eventId);

        assertEq(maxCapacity, newCapacity, "Capacity should be updated");
    }

    function testCannotUpdateCapacityBelowCheckIns() public {
        _events.createEvent(_eventId, _stubId, _pointsAmount, _startTime, _endTime, _maxCapacity);
        address[] memory attendees = new address[](1);
        attendees[0] = _user1;
        _events.setAllowlist(_eventId, attendees, true);

        // Move time to event start and check in
        vm.warp(_startTime);
        vm.startPrank(_user1);
        _events.checkIn(_eventId);
        vm.stopPrank();

        vm.expectRevert("New capacity must be >= current check-ins");
        _events.updateEventCapacity(_eventId, 0);
    }

    function testUpdateEventPoints() public {
        _events.createEvent(_eventId, _stubId, _pointsAmount, _startTime, _endTime, _maxCapacity);

        uint256 newPoints = _pointsAmount + 50;
        _events.updateEventPoints(_eventId, newPoints);

        (, uint256 points,,,,,) = _events.getEventDetails(_eventId);

        assertEq(points, newPoints, "Points should be updated");
    }

    function testCannotUpdatePointsAfterStart() public {
        _events.createEvent(_eventId, _stubId, _pointsAmount, _startTime, _endTime, _maxCapacity);

        // Move time to event start
        vm.warp(_startTime);

        uint256 newPoints = _pointsAmount + 50;
        vm.expectRevert("Cannot modify started event");
        _events.updateEventPoints(_eventId, newPoints);
    }

    function testUpdateEventStub() public {
        _events.createEvent(_eventId, _stubId, _pointsAmount, _startTime, _endTime, _maxCapacity);

        uint256 newStubId = _stubId + 1;
        _events.updateEventStub(_eventId, newStubId);

        (uint256 stubId,,,,,,) = _events.getEventDetails(_eventId);

        assertEq(stubId, newStubId, "Stub ID should be updated");
    }

    function testCannotUpdateStubAfterStart() public {
        _events.createEvent(_eventId, _stubId, _pointsAmount, _startTime, _endTime, _maxCapacity);

        // Move time to event start
        vm.warp(_startTime);

        uint256 newStubId = _stubId + 1;
        vm.expectRevert("Cannot modify started event");
        _events.updateEventStub(_eventId, newStubId);
    }

    function testPauseUnpauseEvent() public {
        _events.createEvent(_eventId, _stubId, _pointsAmount, _startTime, _endTime, _maxCapacity);
        address[] memory attendees = new address[](1);
        attendees[0] = _user1;
        _events.setAllowlist(_eventId, attendees, true);

        // Move time to event start
        vm.warp(_startTime);

        _events.pauseEvent(_eventId);
        (, bool paused,,,) = _events.getEventStatus(_eventId);
        assertTrue(paused, "Event should be paused");

        vm.startPrank(_user1);
        vm.expectRevert("Event is paused");
        _events.checkIn(_eventId);
        vm.stopPrank();

        _events.unpauseEvent(_eventId);
        (, paused,,,) = _events.getEventStatus(_eventId);
        assertFalse(paused, "Event should be unpaused");

        vm.startPrank(_user1);
        _events.checkIn(_eventId);
        vm.stopPrank();
    }

    function testBulkSetAllowlist() public {
        _events.createEvent(_eventId, _stubId, _pointsAmount, _startTime, _endTime, _maxCapacity);

        address[] memory attendees = new address[](3);
        attendees[0] = _user1;
        attendees[1] = _user2;
        attendees[2] = _user3;

        _events.bulkSetAllowlist(_eventId, attendees, true);

        assertTrue(_events.isUserAllowlisted(_eventId, _user1), "User1 should be allowlisted");
        assertTrue(_events.isUserAllowlisted(_eventId, _user2), "User2 should be allowlisted");
        assertTrue(_events.isUserAllowlisted(_eventId, _user3), "User3 should be allowlisted");
    }

    function testBulkRemoveFromAllowlist() public {
        _events.createEvent(_eventId, _stubId, _pointsAmount, _startTime, _endTime, _maxCapacity);

        address[] memory attendees = new address[](2);
        attendees[0] = _user1;
        attendees[1] = _user2;

        _events.bulkSetAllowlist(_eventId, attendees, true);
        _events.bulkRemoveFromAllowlist(_eventId, attendees);

        assertFalse(_events.isUserAllowlisted(_eventId, _user1), "User1 should not be allowlisted");
        assertFalse(_events.isUserAllowlisted(_eventId, _user2), "User2 should not be allowlisted");
    }

    function testDeleteEvent() public {
        _events.createEvent(_eventId, _stubId, _pointsAmount, _startTime, _endTime, _maxCapacity);

        _events.deleteEvent(_eventId);

        (,,,,,, bool exists) = _events.getEventDetails(_eventId);
        assertFalse(exists, "Event should not exist after deletion");
    }

    function testCannotDeleteEventWithCheckIns() public {
        _events.createEvent(_eventId, _stubId, _pointsAmount, _startTime, _endTime, _maxCapacity);
        address[] memory attendees = new address[](1);
        attendees[0] = _user1;
        _events.setAllowlist(_eventId, attendees, true);

        // Move time to event start and check in
        vm.warp(_startTime);
        vm.startPrank(_user1);
        _events.checkIn(_eventId);
        vm.stopPrank();

        vm.expectRevert("Cannot delete event with check-ins");
        _events.deleteEvent(_eventId);
    }

    function testIsEventActive() public {
        _events.createEvent(_eventId, _stubId, _pointsAmount, _startTime, _endTime, _maxCapacity);

        // Before start
        assertFalse(_events.isEventActive(_eventId), "Event should not be active before start");

        // During event
        vm.warp(_startTime);
        assertTrue(_events.isEventActive(_eventId), "Event should be active during event time");

        // After end
        vm.warp(_endTime + 1);
        assertFalse(_events.isEventActive(_eventId), "Event should not be active after end");
    }

    function testUpdateEventStubContract() public {
        // Deploy new Stubs contract
        Stubs newStubs = new Stubs("https://newexample.com/api/token/{id}.json");

        // Set up new Stubs contract
        vm.startPrank(_owner);
        newStubs.transferOwnership(address(_events));
        vm.stopPrank();

        vm.startPrank(address(_events));
        newStubs.setEventsContract(address(_events));
        vm.stopPrank();

        // Update the Stubs contract
        _events.updateEventStubContract(address(newStubs));

        // Verify the update
        assertEq(address(_events.eventStub()), address(newStubs), "Stubs contract should be updated");
    }

    function testUpdateEventPointsContract() public {
        // Deploy new Points contract
        Points newPoints = new Points();

        // Set up new Points contract
        vm.startPrank(_owner);
        newPoints.transferOwnership(address(_events));
        vm.stopPrank();

        vm.startPrank(address(_events));
        newPoints.setEventsContract(address(_events));
        vm.stopPrank();

        // Update the Points contract
        _events.updateEventPointsContract(address(newPoints));

        // Verify the update
        assertEq(address(_events.eventPoints()), address(newPoints), "Points contract should be updated");
    }

    function testCannotUpdateStubContractToZeroAddress() public {
        vm.expectRevert("Invalid Stubs contract address");
        _events.updateEventStubContract(address(0));
    }

    function testCannotUpdatePointsContractToZeroAddress() public {
        vm.expectRevert("Invalid Points contract address");
        _events.updateEventPointsContract(address(0));
    }

    function testCannotUpdateContractsWhenPaused() public {
        // Pause the contract
        _events.pause();

        // Try to update contracts
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("EnforcedPause()"))));
        _events.updateEventStubContract(address(_stubs));

        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("EnforcedPause()"))));
        _events.updateEventPointsContract(address(_points));

        // Unpause to allow other tests to proceed
        _events.unpause();
    }

    function testNonOwnerCannotUpdateContracts() public {
        vm.startPrank(_user1);

        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("OwnableUnauthorizedAccount(address)")), _user1));
        _events.updateEventStubContract(address(_stubs));

        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("OwnableUnauthorizedAccount(address)")), _user1));
        _events.updateEventPointsContract(address(_points));

        vm.stopPrank();
    }

    function testContractUpdateEvents() public {
        // Deploy new contracts
        Stubs newStubs = new Stubs("https://newexample.com/api/token/{id}.json");
        Points newPoints = new Points();

        // Set up new contracts
        vm.startPrank(_owner);
        newStubs.transferOwnership(address(_events));
        newPoints.transferOwnership(address(_events));
        vm.stopPrank();

        vm.startPrank(address(_events));
        newStubs.setEventsContract(address(_events));
        newPoints.setEventsContract(address(_events));
        vm.stopPrank();

        // Update contracts and verify events
        vm.expectEmit(true, true, true, true);
        emit EventStubContractUpdated(address(_stubs), address(newStubs));
        _events.updateEventStubContract(address(newStubs));

        vm.expectEmit(true, true, true, true);
        emit EventPointsContractUpdated(address(_points), address(newPoints));
        _events.updateEventPointsContract(address(newPoints));
    }
}
