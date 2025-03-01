// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/InflationToken.sol";
import "openzeppelin-contracts/token/ERC20/ERC20.sol";

// Mock ERC20 Token for testing recovery
contract MockERC20 is ERC20 {
    constructor() ERC20("OtherToken", "OTK") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract InflationTokenTest is Test {
    InflationToken token;
    address owner = address(this); // set the owner to the test contract
    address user = address(2);
    address user2 = address(3);
    MockERC20 otherToken;

    function setUp() public {
        token = new InflationToken();
        otherToken = new MockERC20();
        console.log("Setup completed. Owner address:", owner, "User address:", user);
    }

    function testInitialSupply() public {
        uint256 initialSupply = 1_000_000_000 * 10 ** token.decimals();
        console.log("Testing Initial Supply");
        console.log("Expected initial supply:", initialSupply);
        console.log("Actual initial supply:", token.totalSupply());
        assertEq(token.totalSupply(), initialSupply);
        console.log("Expected owner balance:", initialSupply);
        console.log("Actual owner balance:", token.balanceOf(owner));
        assertEq(token.balanceOf(owner), initialSupply);
    }

    function testInflation() public {
        uint256 initialSupply = 1_000_000_000 * 10 ** token.decimals();
        console.log("Testing Inflation");
        // fast forward 1 year
        vm.warp(block.timestamp + 365 days);
        console.log("Fast forwarded 1 year");

        uint256 mintAmount = (initialSupply * 4) / 100;
        console.log("Minting 4% of the total supply:", mintAmount);
        token.mint(owner, mintAmount);

        uint256 expectedSupply = initialSupply + mintAmount;
        console.log("Expected supply after minting 4%:", expectedSupply);
        console.log("Actual supply after minting 4%:", token.totalSupply());
        assertEq(token.totalSupply(), expectedSupply);

        // mint another 1% of the total supply
        mintAmount = (token.totalSupply() * 1) / 100;
        console.log("Minting 1% of the total supply:", mintAmount);
        token.mint(owner, mintAmount);

        expectedSupply += mintAmount;
        console.log("Expected supply after minting another 1%:", expectedSupply);
        console.log("Actual supply after minting another 1%:", token.totalSupply());
        assertEq(token.totalSupply(), expectedSupply);

        // try to mint another 1%, should fail due to cap
        mintAmount = (token.totalSupply() * 1) / 100;
        console.log("Attempting to mint another 1%, expecting revert due to cap");
        vm.expectRevert(InflationToken.MintCapExceeded.selector);
        token.mint(owner, mintAmount);

        // fast forward another year and ensure minting works again
        vm.warp(block.timestamp + 365 days);
        console.log("Fast forwarded another year");
        token.mint(owner, mintAmount);
        expectedSupply += mintAmount;
        console.log("Expected supply after minting another 1%:", expectedSupply);
        console.log("Actual supply after minting another 1%:", token.totalSupply());
        assertEq(token.totalSupply(), expectedSupply);
    }

    function testMintToContractAddressBlocked() public {
        vm.warp(block.timestamp + 365 days);
        uint256 mintAmount = (token.totalSupply() * 1) / 100;

        console.log("Attempting to mint to contract address, expecting revert");
        vm.expectRevert(InflationToken.MintToContractAddressBlocked.selector);
        token.mint(address(token), mintAmount);
    }

    function testRecoverTokens() public {
        vm.warp(block.timestamp + 365 days);
        uint256 mintAmount = (token.totalSupply() * 1) / 100;
        token.mint(owner, mintAmount);
        token.transfer(address(token), mintAmount);

        uint256 contractBalanceBefore = token.balanceOf(address(token));
        console.log("Contract balance before recovery:", contractBalanceBefore);
        uint256 ownerBalanceBefore = token.balanceOf(owner);
        console.log("Owner balance before recovery:", ownerBalanceBefore);

        token.recoverTokens(address(token), mintAmount, owner);

        uint256 contractBalanceAfter = token.balanceOf(address(token));
        uint256 ownerBalanceAfter = token.balanceOf(owner);
        console.log("Contract balance after recovery:", contractBalanceAfter);
        console.log("Owner balance after recovery:", ownerBalanceAfter);

        assertEq(contractBalanceAfter, contractBalanceBefore - mintAmount);
        assertEq(ownerBalanceAfter, ownerBalanceBefore + mintAmount);
    }

    function testTotalSupplyAfterInflation() public {
        console.log("Testing Total Supply After Inflation for 5 years");
        console.log("Inflation is a constant 5% of the initial supply on launch");
        uint256 initialSupply = 1_000_000_000 * 10 ** token.decimals();
        uint256 mintAmount = (initialSupply * 5) / 100; // Flat 5% of the initial supply each year

        for (uint256 year = 1; year <= 5; year++) {
            vm.warp(block.timestamp + 365 days);
            token.mint(owner, mintAmount);
            uint256 expectedSupply = initialSupply + (mintAmount * year);
            console.log("Year", year, "- Minted amount:", mintAmount);
            console.log("Year", year, "- Expected Total Supply:", expectedSupply);
            console.log("Year", year, "- Actual Total Supply:", token.totalSupply());
            assertEq(token.totalSupply(), expectedSupply);
        }
    }

    function testPauseAndUnpause() public {
        console.log("Testing Pause and Unpause");
        token.pause();
        console.log("Contract paused");

        // Expect revert with EnforcedPause error
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        token.transfer(user, 1);

        token.unpause();
        console.log("Contract unpaused");
        token.transfer(user, 1);
        console.log("Transferred 1 token to user");
        assertEq(token.balanceOf(user), 1);
    }

    function testPauseAndUnpauseByNonOwner() public {
        vm.prank(user);
        console.log("Attempting to pause contract as non-owner, expecting revert");

        // Expect revert with OwnableUnauthorizedAccount error
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user));
        token.pause();
    }

    function testDelegationAndVoting() public {
        console.log("Testing Delegation and Voting");

        // User delegates votes to themselves
        vm.prank(user);
        token.delegate(user);
        console.log("User delegated votes to themselves");

        // Get initial votes for user
        uint256 initialVotes = token.getVotes(user);
        console.log("Initial votes for user:", initialVotes);

        // Transfer 100 tokens to the user
        token.transfer(user, 100);
        console.log("Transferred 100 tokens to user");

        // User delegates votes to themselves again after transfer
        vm.prank(user);
        token.delegate(user);
        console.log("User re-delegated votes to themselves");

        // Calculate expected votes after transfer and re-delegation
        uint256 expectedVotes = initialVotes + 100;
        uint256 actualVotes = token.getVotes(user);
        console.log("Expected votes for user after transfer and re-delegation:", expectedVotes);
        console.log("Actual votes for user after transfer and re-delegation:", actualVotes);

        assertEq(actualVotes, expectedVotes);

        // User delegates votes to another user (user2)
        vm.prank(user);
        token.delegate(user2);
        console.log("User delegated votes to user2");

        // Check balance of user2 (should be zero tokens, but have delegated votes)
        uint256 user2Votes = token.getVotes(user2);
        console.log("Votes for user2 after delegation from user:", user2Votes);

        uint256 user2ExpectedVotes = expectedVotes; // All votes should now be delegated to user2
        console.log("Expected votes for user2 after delegation:", user2ExpectedVotes);
        assertEq(user2Votes, user2ExpectedVotes);
    }

    function testTransferOwnership() public {
        console.log("Testing Ownership Transfer");

        // Transfer ownership to user
        token.transferOwnership(user);
        console.log("Ownership transferred to user");

        // Prank as new owner and pause the contract
        vm.prank(user);
        token.pause();
        console.log("Contract paused by new owner");

        // Prank as old owner and expect revert when trying to unpause
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", owner));
        token.unpause();
    }

    function testTokenTransfers() public {
        console.log("Testing Token Transfers");
        uint256 ownerBalanceBefore = token.balanceOf(owner);
        console.log("Owner balance before transfer:", ownerBalanceBefore);
        token.transfer(user, 100);
        console.log("Transferred 100 tokens to user");
        assertEq(token.balanceOf(user), 100);
        console.log("User balance after transfer:", token.balanceOf(user));
        assertEq(token.balanceOf(owner), ownerBalanceBefore - 100);
        console.log("Owner balance after transfer:", token.balanceOf(owner));
    }

    function testRecoverOtherToken() public {
        console.log("Testing Recover Other Token");
        otherToken.mint(address(token), 100);
        console.log("Transferred 100 OtherToken to contract");
        token.recoverTokens(address(otherToken), 100, owner);
        console.log("Recovered 100 OtherToken from contract to owner");
        assertEq(otherToken.balanceOf(owner), 100);
    }

    function testBurnTokens() public {
        console.log("Testing Token Burning");
        uint256 initialSupply = token.totalSupply();
        console.log("Initial total supply:", initialSupply);
        token.burn(100);
        console.log("Burned 100 tokens");
        assertEq(token.totalSupply(), initialSupply - 100);
        console.log("Total supply after burning:", token.totalSupply());
    }

    function testMintingInThePastReverts() public {
        console.log("Testing Minting in the Past Reverts");

        // Warp to a future timestamp to simulate past minting allowed time
        uint256 futureTime = block.timestamp + 365 days;
        vm.warp(futureTime);

        // Set minting allowed time to a past time
        uint256 mintingAllowedAfter = block.timestamp - 1;

        // Expect revert with MintAllowedAfterDeployOnly error
        vm.expectRevert(
            abi.encodeWithSelector(
                InflationToken.MintAllowedAfterDeployOnly.selector, block.timestamp, mintingAllowedAfter
            )
        );
        new InflationToken(mintingAllowedAfter);
    }

    function testCannotReceiveEth() public {
        vm.expectRevert(bytes("Contract should not accept ETH"));
        (bool success,) = address(token).call{value: 1 ether}("");
        console.log("ETH transfer success status:", success);
        assertFalse(success, "Contract should not be able to accept ETH");
    }

    function testAccess() public {
        console.log("Testing access to token attributes and ownership");
        assertEq(token.name(), "InflationToken", "Token name should be InflationToken");
        assertEq(token.symbol(), "INFLA", "Token symbol should be INFLA");
        assertEq(token.decimals(), 18, "Token decimals should be 18");
        assertEq(token.totalSupply(), 1_000_000_000 * 10 ** token.decimals(), "Total supply should be 1 billion");
        assertEq(token.owner(), owner, "Owner should be the initial owner");
    }
}
