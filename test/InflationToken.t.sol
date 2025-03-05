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

        // Try minting after 1 day - should fail
        vm.warp(block.timestamp + 1 days);
        console.log("Fast forwarded 1 day");
        vm.expectRevert(InflationToken.MintingDateNotReached.selector);
        token.mint(owner);

        // Try minting after 1 year - should succeed
        vm.warp(block.timestamp + 365 days);
        console.log("Fast forwarded to 1 year");
        token.mint(owner);
        assertEq(token.totalSupply(), initialSupply + token.MINT_CAP());

        // Try minting after 1 more day - should fail
        vm.warp(block.timestamp + 1 days);
        console.log("Fast forwarded 1 more day");
        vm.expectRevert(InflationToken.MintingDateNotReached.selector);
        token.mint(owner);

        // Try minting after another year - should succeed
        vm.warp(block.timestamp + 365 days);
        console.log("Fast forwarded to 2 years");
        token.mint(owner);
        assertEq(token.totalSupply(), initialSupply + (token.MINT_CAP() * 2));
    }

    function testMintToContractAddressBlocked() public {
        vm.warp(block.timestamp + 365 days);

        console.log("Attempting to mint to contract address, expecting revert");
        vm.expectRevert(InflationToken.CannotMintToBlockedAddress.selector);
        token.mint(address(token));
    }

    function testRecoverTokens() public {
        vm.warp(block.timestamp + 365 days);
        token.mint(owner);
        token.transfer(address(token), token.MINT_CAP());

        uint256 contractBalanceBefore = token.balanceOf(address(token));
        console.log("Contract balance before recovery:", contractBalanceBefore);
        uint256 ownerBalanceBefore = token.balanceOf(owner);
        console.log("Owner balance before recovery:", ownerBalanceBefore);

        token.recoverTokens(address(token), token.MINT_CAP(), owner);

        uint256 contractBalanceAfter = token.balanceOf(address(token));
        uint256 ownerBalanceAfter = token.balanceOf(owner);
        console.log("Contract balance after recovery:", contractBalanceAfter);
        console.log("Owner balance after recovery:", ownerBalanceAfter);

        assertEq(contractBalanceAfter, contractBalanceBefore - token.MINT_CAP());
        assertEq(ownerBalanceAfter, ownerBalanceBefore + token.MINT_CAP());
    }

    function testTotalSupplyAfterInflation() public {
        console.log("Testing Total Supply After Inflation for 5 years");
        console.log("Inflation is a constant 5% of the initial supply each year");
        uint256 initialSupply = 1_000_000_000 * 10 ** token.decimals();

        for (uint256 year = 1; year <= 5; year++) {
            vm.warp(block.timestamp + 365 days);
            token.mint(owner);
            uint256 expectedSupply = initialSupply + (token.MINT_CAP() * year);
            console.log("Year", year, "- Minted amount:", token.MINT_CAP());
            console.log("Year", year, "- Expected Total Supply:", expectedSupply);
            console.log("Year", year, "- Actual Total Supply:", token.totalSupply());
            assertEq(token.totalSupply(), expectedSupply);
        }
    }

    function testTransferOwnership() public {
        console.log("Testing Ownership Transfer");
        token.transferOwnership(user);
        console.log("Ownership transferred to user");
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
