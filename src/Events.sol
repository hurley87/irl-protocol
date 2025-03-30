// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "openzeppelin-contracts/access/Ownable.sol";
import "./Stubs.sol";
import "./Points.sol";

contract Events is Ownable {
    Stubs public eventStub;
    Points public eventPoints;

    struct EventInfo {
        uint256 stubId;
        uint256 points;
        uint256 startTime;
        uint256 endTime;
        uint256 maxCapacity;
        uint256 totalCheckedIn;
        bool exists;
    }

    mapping(uint256 => EventInfo) public events;
    mapping(uint256 => mapping(address => bool)) public allowlist;
    mapping(uint256 => mapping(address => bool)) public checkedIn;

    event CheckedIn(uint256 indexed eventId, address indexed user, uint256 points, uint256 stubId);
    event CheckInReversed(uint256 indexed eventId, address indexed user);

    constructor(address _eventStub, address _eventPoints) Ownable(msg.sender) {
        eventStub = Stubs(_eventStub);
        eventPoints = Points(_eventPoints);
    }

    function createEvent(
        uint256 eventId,
        uint256 stubId,
        uint256 points,
        uint256 startTime,
        uint256 endTime,
        uint256 maxCapacity
    ) external onlyOwner {
        require(!events[eventId].exists, "Event already exists");
        require(startTime < endTime, "Invalid time range");
        events[eventId] = EventInfo(stubId, points, startTime, endTime, maxCapacity, 0, true);
    }

    function setAllowlist(uint256 eventId, address[] calldata attendees, bool allowed) external onlyOwner {
        require(events[eventId].exists, "Event doesn't exist");
        for (uint256 i = 0; i < attendees.length; i++) {
            allowlist[eventId][attendees[i]] = allowed;
        }
    }

    function checkIn(uint256 eventId) external {
        EventInfo storage evt = events[eventId];
        require(evt.exists, "Event doesn't exist");
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

    // Admin function to undo check-in if needed
    function undoCheckIn(uint256 eventId, address attendee) external onlyOwner {
        EventInfo storage evt = events[eventId];
        require(checkedIn[eventId][attendee], "User not checked in");

        checkedIn[eventId][attendee] = false;
        evt.totalCheckedIn -= 1;

        eventStub.burn(attendee, evt.stubId, 1);
        eventPoints.burnFrom(attendee, evt.points);

        emit CheckInReversed(eventId, attendee);
    }

}