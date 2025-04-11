// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin-contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import "./Stubs.sol";
import "./Points.sol";

/// @title Events Contract
/// @notice Manages event creation, check-ins, and rewards distribution
/// @dev Handles event lifecycle, allowlist management, and points/stub distribution
contract Events is Initializable, Ownable2StepUpgradeable, PausableUpgradeable, UUPSUpgradeable {
    Stubs public eventStub;
    Points public eventPoints;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the contract with required dependencies
    /// @param _eventStub Address of the Stubs contract for NFT minting
    /// @param _eventPoints Address of the Points contract for points distribution
    function initialize(address _eventStub, address _eventPoints) public initializer {
        __Ownable2Step_init();
        __Pausable_init();
        __UUPSUpgradeable_init();
        eventStub = Stubs(_eventStub);
        eventPoints = Points(_eventPoints);
        _transferOwnership(msg.sender);
    }

    /// @notice Authorizes an upgrade to a new implementation
    /// @param newImplementation Address of the new implementation
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /// @notice Structure containing all information about an event
    /// @param stubId The ID of the stub NFT to be minted on check-in
    /// @param points The number of points to be awarded on check-in
    /// @param startTime Unix timestamp when the event starts
    /// @param endTime Unix timestamp when the event ends
    /// @param maxCapacity Maximum number of attendees allowed
    /// @param totalCheckedIn Current number of checked-in attendees
    /// @param exists Whether the event exists
    /// @param paused Whether the event is currently paused
    struct EventInfo {
        uint256 stubId;
        uint256 points;
        uint256 startTime;
        uint256 endTime;
        uint256 maxCapacity;
        uint256 totalCheckedIn;
        bool exists;
        bool paused;
    }

    mapping(uint256 => EventInfo) public events;
    mapping(uint256 => mapping(address => bool)) public allowlist;
    mapping(uint256 => mapping(address => bool)) public checkedIn;

    event CheckedIn(uint256 indexed eventId, address indexed user, uint256 points, uint256 stubId);
    event CheckInReversed(uint256 indexed eventId, address indexed user);
    event EventEnded(uint256 indexed eventId);
    event EventUpdated(uint256 indexed eventId, uint256 startTime, uint256 endTime, uint256 maxCapacity);
    event EventPointsUpdated(uint256 indexed eventId, uint256 newPoints);
    event EventStubUpdated(uint256 indexed eventId, uint256 newStubId);
    event EventPaused(uint256 indexed eventId);
    event EventUnpaused(uint256 indexed eventId);
    event EventDeleted(uint256 indexed eventId);
    event BulkAllowlistUpdated(uint256 indexed eventId, uint256 count);
    event EventCreated(
        uint256 indexed eventId, uint256 stubId, uint256 points, uint256 startTime, uint256 endTime, uint256 maxCapacity
    );
    event AllowlistUpdated(uint256 indexed eventId, address indexed user, bool allowed);
    event EventCapacityUpdated(uint256 indexed eventId, uint256 oldCapacity, uint256 newCapacity);
    event EventTimesUpdated(
        uint256 indexed eventId, uint256 oldStartTime, uint256 oldEndTime, uint256 newStartTime, uint256 newEndTime
    );

    /// @notice Pauses the entire contract
    /// @dev Only callable by contract owner
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpauses the entire contract
    /// @dev Only callable by contract owner
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice Creates a new event with specified parameters
    /// @param eventId Unique identifier for the event
    /// @param stubId ID of the stub NFT to be minted
    /// @param points Points to be awarded on check-in
    /// @param startTime Unix timestamp when the event starts
    /// @param endTime Unix timestamp when the event ends
    /// @param maxCapacity Maximum number of attendees allowed
    /// @dev Only callable by contract owner
    function createEvent(
        uint256 eventId,
        uint256 stubId,
        uint256 points,
        uint256 startTime,
        uint256 endTime,
        uint256 maxCapacity
    ) external onlyOwner whenNotPaused {
        require(!events[eventId].exists, "Event already exists");
        require(startTime < endTime, "Invalid time range");
        events[eventId] = EventInfo(stubId, points, startTime, endTime, maxCapacity, 0, true, false);
        emit EventCreated(eventId, stubId, points, startTime, endTime, maxCapacity);
    }

    /// @notice Sets allowlist status for multiple attendees
    /// @param eventId ID of the event
    /// @param attendees Array of attendee addresses
    /// @param allowed Whether to allow or disallow the attendees
    /// @dev Only callable by contract owner
    function setAllowlist(uint256 eventId, address[] calldata attendees, bool allowed)
        external
        onlyOwner
        whenNotPaused
    {
        require(events[eventId].exists, "Event doesn't exist");
        for (uint256 i = 0; i < attendees.length; i++) {
            allowlist[eventId][attendees[i]] = allowed;
            emit AllowlistUpdated(eventId, attendees[i], allowed);
        }
    }

    /// @notice Allows an attendee to check in to an event
    /// @param eventId ID of the event to check in to
    /// @dev Mints stub NFT and points to the attendee upon successful check-in
    function checkIn(uint256 eventId) external whenNotPaused {
        EventInfo storage evt = events[eventId];
        require(evt.exists, "Event doesn't exist");
        require(!evt.paused, "Event is paused");
        require(block.timestamp >= evt.startTime, "Check-in hasn't started");
        require(block.timestamp <= evt.endTime, "Check-in period ended");
        require(evt.totalCheckedIn < evt.maxCapacity, "Event at max capacity");
        require(allowlist[eventId][msg.sender], "Not on allowlist");
        require(!checkedIn[eventId][msg.sender], "Already checked in");

        checkedIn[eventId][msg.sender] = true;
        evt.totalCheckedIn += 1;

        eventStub.mint(msg.sender, evt.stubId, 1);
        eventPoints.mint(msg.sender, evt.points);

        emit CheckedIn(eventId, msg.sender, evt.points, evt.stubId);
    }

    /// @notice Manually ends an event before its scheduled end time
    /// @param eventId ID of the event to end
    /// @dev Only callable by contract owner
    function autoEndEvent(uint256 eventId) external onlyOwner whenNotPaused {
        EventInfo storage evt = events[eventId];
        require(evt.exists, "Event doesn't exist");
        require(block.timestamp <= evt.endTime, "Event already ended");

        evt.endTime = block.timestamp;
        emit EventEnded(eventId);
    }

    /// @notice Updates the start and end times of an event
    /// @param eventId ID of the event to update
    /// @param newStartTime New start time (Unix timestamp)
    /// @param newEndTime New end time (Unix timestamp)
    /// @dev Only callable by contract owner. Cannot modify started events.
    function updateEventTimes(uint256 eventId, uint256 newStartTime, uint256 newEndTime)
        external
        onlyOwner
        whenNotPaused
    {
        EventInfo storage evt = events[eventId];
        require(evt.exists, "Event doesn't exist");
        require(newStartTime < newEndTime, "Invalid time range");
        require(block.timestamp < evt.startTime, "Cannot modify started event");

        emit EventTimesUpdated(eventId, evt.startTime, evt.endTime, newStartTime, newEndTime);

        evt.startTime = newStartTime;
        evt.endTime = newEndTime;

        emit EventUpdated(eventId, newStartTime, newEndTime, evt.maxCapacity);
    }

    /// @notice Updates the maximum capacity of an event
    /// @param eventId ID of the event to update
    /// @param newMaxCapacity New maximum capacity
    /// @dev Only callable by contract owner. New capacity must be >= current check-ins.
    function updateEventCapacity(uint256 eventId, uint256 newMaxCapacity) external onlyOwner whenNotPaused {
        EventInfo storage evt = events[eventId];
        require(evt.exists, "Event doesn't exist");
        require(newMaxCapacity >= evt.totalCheckedIn, "New capacity must be >= current check-ins");

        uint256 oldCapacity = evt.maxCapacity;
        evt.maxCapacity = newMaxCapacity;

        emit EventCapacityUpdated(eventId, oldCapacity, newMaxCapacity);
        emit EventUpdated(eventId, evt.startTime, evt.endTime, newMaxCapacity);
    }

    /// @notice Updates the points awarded for event check-in
    /// @param eventId ID of the event to update
    /// @param newPoints New number of points to award
    /// @dev Only callable by contract owner. Cannot modify started events.
    function updateEventPoints(uint256 eventId, uint256 newPoints) external onlyOwner whenNotPaused {
        EventInfo storage evt = events[eventId];
        require(evt.exists, "Event doesn't exist");
        require(block.timestamp < evt.startTime, "Cannot modify started event");

        evt.points = newPoints;
        emit EventPointsUpdated(eventId, newPoints);
    }

    /// @notice Updates the stub NFT ID for an event
    /// @param eventId ID of the event to update
    /// @param newStubId New stub NFT ID
    /// @dev Only callable by contract owner. Cannot modify started events.
    function updateEventStub(uint256 eventId, uint256 newStubId) external onlyOwner whenNotPaused {
        EventInfo storage evt = events[eventId];
        require(evt.exists, "Event doesn't exist");
        require(block.timestamp < evt.startTime, "Cannot modify started event");

        evt.stubId = newStubId;
        emit EventStubUpdated(eventId, newStubId);
    }

    /// @notice Retrieves all details of an event
    /// @param eventId ID of the event to query
    /// @return stubId The stub NFT ID
    /// @return points Points awarded on check-in
    /// @return startTime Event start time
    /// @return endTime Event end time
    /// @return maxCapacity Maximum allowed attendees
    /// @return totalCheckedIn Current number of check-ins
    /// @return exists Whether the event exists
    function getEventDetails(uint256 eventId)
        external
        view
        returns (
            uint256 stubId,
            uint256 points,
            uint256 startTime,
            uint256 endTime,
            uint256 maxCapacity,
            uint256 totalCheckedIn,
            bool exists
        )
    {
        EventInfo storage evt = events[eventId];
        return (evt.stubId, evt.points, evt.startTime, evt.endTime, evt.maxCapacity, evt.totalCheckedIn, evt.exists);
    }

    /// @notice Pauses an event, preventing check-ins
    /// @param eventId ID of the event to pause
    /// @dev Only callable by contract owner
    function pauseEvent(uint256 eventId) external onlyOwner {
        EventInfo storage evt = events[eventId];
        require(evt.exists, "Event doesn't exist");
        require(!evt.paused, "Event already paused");

        evt.paused = true;
        emit EventPaused(eventId);
    }

    /// @notice Unpauses a previously paused event
    /// @param eventId ID of the event to unpause
    /// @dev Only callable by contract owner
    function unpauseEvent(uint256 eventId) external onlyOwner {
        EventInfo storage evt = events[eventId];
        require(evt.exists, "Event doesn't exist");
        require(evt.paused, "Event not paused");

        evt.paused = false;
        emit EventUnpaused(eventId);
    }

    /// @notice Bulk updates allowlist status for multiple attendees
    /// @param eventId ID of the event
    /// @param attendees Array of attendee addresses
    /// @param allowed Whether to allow or disallow the attendees
    /// @dev Only callable by contract owner
    function bulkSetAllowlist(uint256 eventId, address[] calldata attendees, bool allowed) external onlyOwner {
        require(events[eventId].exists, "Event doesn't exist");
        uint256 count = 0;
        for (uint256 i = 0; i < attendees.length; i++) {
            allowlist[eventId][attendees[i]] = allowed;
            count++;
        }
        emit BulkAllowlistUpdated(eventId, count);
    }

    /// @notice Bulk removes multiple addresses from the allowlist
    /// @param eventId ID of the event
    /// @param attendees Array of attendee addresses to remove
    /// @dev Only callable by contract owner
    function bulkRemoveFromAllowlist(uint256 eventId, address[] calldata attendees) external onlyOwner {
        require(events[eventId].exists, "Event doesn't exist");
        for (uint256 i = 0; i < attendees.length; i++) {
            allowlist[eventId][attendees[i]] = false;
        }
    }

    /// @notice Deletes an event (emergency use only)
    /// @param eventId ID of the event to delete
    /// @dev Only callable by contract owner. Cannot delete events with check-ins.
    function deleteEvent(uint256 eventId) external onlyOwner {
        EventInfo storage evt = events[eventId];
        require(evt.exists, "Event doesn't exist");
        require(evt.totalCheckedIn == 0, "Cannot delete event with check-ins");

        delete events[eventId];
        emit EventDeleted(eventId);
    }

    /// @notice Checks if an event is currently active
    /// @param eventId ID of the event to check
    /// @return bool Whether the event is active
    function isEventActive(uint256 eventId) external view returns (bool) {
        EventInfo storage evt = events[eventId];
        return evt.exists && !evt.paused && block.timestamp >= evt.startTime && block.timestamp <= evt.endTime
            && evt.totalCheckedIn < evt.maxCapacity;
    }

    /// @notice Gets comprehensive status information about an event
    /// @param eventId ID of the event to check
    /// @return exists Whether the event exists
    /// @return paused Whether the event is paused
    /// @return hasStarted Whether the event has started
    /// @return hasEnded Whether the event has ended
    /// @return isAtCapacity Whether the event is at capacity
    function getEventStatus(uint256 eventId)
        external
        view
        returns (bool exists, bool paused, bool hasStarted, bool hasEnded, bool isAtCapacity)
    {
        EventInfo storage evt = events[eventId];
        return (
            evt.exists,
            evt.paused,
            block.timestamp >= evt.startTime,
            block.timestamp > evt.endTime,
            evt.totalCheckedIn >= evt.maxCapacity
        );
    }

    /// @notice Gets the current number of check-ins for an event
    /// @param eventId ID of the event to check
    /// @return uint256 Number of check-ins
    function getEventCheckInCount(uint256 eventId) external view returns (uint256) {
        return events[eventId].totalCheckedIn;
    }

    /// @notice Checks if a user has checked in to an event
    /// @param eventId ID of the event to check
    /// @param user Address of the user to check
    /// @return bool Whether the user has checked in
    function isUserCheckedIn(uint256 eventId, address user) external view returns (bool) {
        return checkedIn[eventId][user];
    }

    /// @notice Checks if a user is on the allowlist for an event
    /// @param eventId ID of the event to check
    /// @param user Address of the user to check
    /// @return bool Whether the user is allowlisted
    function isUserAllowlisted(uint256 eventId, address user) external view returns (bool) {
        return allowlist[eventId][user];
    }
}
