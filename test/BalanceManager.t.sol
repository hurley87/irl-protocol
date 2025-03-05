// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/BalanceManager.sol";
import "openzeppelin-contracts/token/ERC20/ERC20.sol";

/**
 * @title MockERC20
 * @dev Minimal ERC20 implementation.
 */
contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1000000 * 10 ** 18); // Mint initial supply to the deployer
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/**
 * @title BalanceManager Test
 * @dev Test contract for BalanceManager contract. This test suite covers an
 *      extensive amount all the core functionality of the contract, including
 *      fuzz examples of most of the unit tests.
 */
contract BalanceManagerTest is Test {
    BalanceManager balanceManager;
    MockERC20 mockTokenA;
    MockERC20 mockTokenB;
    MockERC20 mockTokenC;
    address owner;
    address admin1;
    address admin2;
    address user1;
    address user2;

    uint256 threeHundred = 300 * 10 ** 18;
    uint256 fiveHundred = 500 * 10 ** 18;
    uint256 oneThousand = 1000 * 10 ** 18;
    uint256 hundredThousand = 100000 * 10 ** 18;

    function setUp() public {
        owner = address(this);
        admin1 = vm.addr(1);
        admin2 = vm.addr(2);
        user1 = vm.addr(3);
        user2 = vm.addr(4);

        // Deploy the BalanceManager contract with the owner address
        balanceManager = new BalanceManager(owner);

        // Deploy the test tokens
        mockTokenA = new MockERC20("Token A", "AMKT");
        mockTokenB = new MockERC20("Token B", "BMKT");
        mockTokenC = new MockERC20("Token C", "CMKT");

        // Mint tokens to the admins
        mockTokenA.mint(admin1, hundredThousand);
        mockTokenA.mint(admin2, hundredThousand);

        mockTokenB.mint(admin1, hundredThousand);
        mockTokenB.mint(admin2, hundredThousand);

        mockTokenC.mint(admin1, hundredThousand);
        mockTokenC.mint(admin2, hundredThousand);

        // Mint tokens to the users
        mockTokenA.mint(user1, hundredThousand);
        mockTokenC.mint(user1, hundredThousand);

        mockTokenB.mint(user2, hundredThousand);

        // Set admin roles
        balanceManager.addAdmin(admin1);
        balanceManager.addAdmin(admin2);

        // Log the token addresses and user/admin addresses
        console.log("Token A address:", address(mockTokenA));
        console.log("Token B address:", address(mockTokenB));
        console.log("Token C address:", address(mockTokenC));
        console.log("Owner address:", owner);
        console.log("Admin1 address:", admin1);
        console.log("Admin2 address:", admin2);
        console.log("User1 address:", user1);
        console.log("User2 address:", user2);
    }

    function testAddRemoveAdmin() public {
        address newAdmin = vm.addr(5);

        // Add new admin
        balanceManager.addAdmin(newAdmin);
        assertTrue(balanceManager.admins(newAdmin), "New admin should be added");
        console.log("Added new admin:", newAdmin);

        // Remove new admin
        balanceManager.removeAdmin(newAdmin);
        assertFalse(balanceManager.admins(newAdmin), "New admin should be removed");
        console.log("Removed new admin:", newAdmin);
    }

    function testRemovedAdminWorks() public {
        vm.startPrank(owner);

        // Add user1 as admin
        balanceManager.addAdmin(user1);
        assertTrue(balanceManager.isAdmin(user1), "User1 should be added as an admin");
        console.log("Owner added User1 as admin");

        // User1 sets balance for User2
        uint256 amount = 500 * 10 ** 18;
        vm.stopPrank();
        vm.startPrank(user1);
        balanceManager.setBalance(user2, address(mockTokenA), amount);
        console.log("User1 set balance for User2 to:", amount);
        assertEq(balanceManager.getBalance(user2, address(mockTokenA)), amount, "User2 balance should be set");

        // Remove user1 as admin
        vm.stopPrank();
        vm.startPrank(owner);
        balanceManager.removeAdmin(user1);
        assertFalse(balanceManager.isAdmin(user1), "User1 should be removed as admin");
        console.log("Owner removed User1 as admin");

        // User1 attempts to set balance for User2 again
        vm.stopPrank();
        vm.startPrank(user1);
        vm.expectRevert("Caller is not an admin");
        balanceManager.setBalance(user2, address(mockTokenA), amount);
        console.log("User1 attempted to set balance for User2 and failed as expected after being removed as admin");

        vm.stopPrank();
    }

    function testUserCannotCallAdmin() public {
        vm.startPrank(user1);

        // Attempt to set balance as a regular user
        vm.expectRevert("Caller is not an admin");
        balanceManager.setBalance(user2, address(mockTokenA), fiveHundred);
        console.log("User1 attempted to set balance for User2 and failed as expected");

        // Attempt to add an admin as a regular user
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user1));
        balanceManager.addAdmin(user1);
        console.log("User1 attempted to add themselves as an admin and failed as expected");

        // Attempt to remove an admin as a regular user
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user1));
        balanceManager.removeAdmin(admin1);
        console.log("User1 attempted to remove Admin1 and failed as expected");

        vm.stopPrank();
    }

    function testSetBalance() public {
        vm.startPrank(admin1);

        console.log("Initial balance:", balanceManager.balances(user1, address(mockTokenA)));
        balanceManager.setBalance(user1, address(mockTokenA), fiveHundred);
        console.log("Set balance:", fiveHundred);
        assertEq(balanceManager.balances(user1, address(mockTokenA)), fiveHundred, "Balance should be set");
        assertEq(balanceManager.totalBalances(address(mockTokenA)), fiveHundred, "Total balance should be updated");
        console.log("Expected balance:", fiveHundred);
        console.log("Actual balance:", balanceManager.balances(user1, address(mockTokenA)));

        vm.stopPrank();
    }

    function testIncreaseBalance() public {
        vm.startPrank(admin1);

        uint256 initialAmount = 300 * 10 ** 18;
        balanceManager.setBalance(user1, address(mockTokenA), initialAmount);
        console.log("Initial balance for user1:", initialAmount);

        uint256 increaseAmount = 200 * 10 ** 18;
        balanceManager.increaseBalance(user1, address(mockTokenA), increaseAmount);
        console.log("Increase user1 balance by:", increaseAmount);

        uint256 expectedBalance = initialAmount + increaseAmount;
        assertEq(balanceManager.balances(user1, address(mockTokenA)), expectedBalance, "Balance should be increased");
        assertEq(balanceManager.totalBalances(address(mockTokenA)), expectedBalance, "Total balance should be updated");
        console.log("Expected user1 balance:", expectedBalance);
        console.log("Actual user1 balance:", balanceManager.balances(user1, address(mockTokenA)));

        vm.stopPrank();
    }

    function testReduceBalance() public {
        vm.startPrank(admin1);

        uint256 initialAmount = 500 * 10 ** 18;
        balanceManager.setBalance(user1, address(mockTokenA), initialAmount);
        console.log("Initial balance for user1:", initialAmount);

        uint256 reduceAmount = 200 * 10 ** 18;
        balanceManager.reduceBalance(user1, address(mockTokenA), reduceAmount);
        console.log("Reduce user1 balance by:", reduceAmount);

        uint256 expectedBalance = initialAmount - reduceAmount;
        assertEq(balanceManager.balances(user1, address(mockTokenA)), expectedBalance, "Balance should be reduced");
        assertEq(balanceManager.totalBalances(address(mockTokenA)), expectedBalance, "Total balance should be updated");
        console.log("Expected user1 balance:", expectedBalance);
        console.log("Actual user1 balance:", balanceManager.balances(user1, address(mockTokenA)));

        vm.stopPrank();
    }

    function testFuzzSetBalance(uint256 amount) public {
        vm.assume(amount <= hundredThousand);
        vm.startPrank(admin1);

        console.log("Setting balance for user1 to", amount);
        balanceManager.setBalance(user1, address(mockTokenA), amount);

        uint256 balance = balanceManager.getBalance(user1, address(mockTokenA));
        console.log("Balance for user1 after setting:", balance);

        assertEq(balance, amount, "Balance should match the set amount");
        vm.stopPrank();
    }

    function testFuzzIncreaseBalance(uint256 amount) public {
        vm.assume(amount <= hundredThousand);
        vm.startPrank(admin1);

        console.log("Increasing balance for user1 by", amount);
        balanceManager.increaseBalance(user1, address(mockTokenA), amount);

        uint256 balance = balanceManager.getBalance(user1, address(mockTokenA));
        console.log("Balance for user1 after increase:", balance);

        assertEq(balance, amount, "Balance should match the increased amount");
        vm.stopPrank();
    }

    function testFuzzReduceBalance(uint256 initialAmount, uint256 reduceAmount) public {
        vm.assume(initialAmount <= hundredThousand);
        vm.assume(reduceAmount <= initialAmount);

        vm.startPrank(admin1);

        console.log("Setting initial balance for user1 to", initialAmount);
        balanceManager.setBalance(user1, address(mockTokenA), initialAmount);

        console.log("Reducing balance for user1 by", reduceAmount);
        balanceManager.reduceBalance(user1, address(mockTokenA), reduceAmount);

        uint256 balance = balanceManager.getBalance(user1, address(mockTokenA));
        console.log("Balance for user1 after reduction:", balance);

        assertEq(balance, initialAmount - reduceAmount, "Balance should match the reduced amount");
        vm.stopPrank();
    }

    function testClaimBalance() public {
        vm.startPrank(admin1);

        uint256 amount = 500 * 10 ** 18;
        balanceManager.setBalance(user1, address(mockTokenA), amount);

        vm.stopPrank();

        // Fund the contract with tokens
        vm.startPrank(user1);
        mockTokenA.approve(address(balanceManager), amount);
        balanceManager.fund(address(mockTokenA), amount);
        console.log("Funded contract with tokens:", amount);
        vm.stopPrank();

        uint256 initialBalance = mockTokenA.balanceOf(user1);
        console.log("Initial User1 Token A balance:", initialBalance);

        vm.startPrank(user1);
        balanceManager.claim(address(mockTokenA));
        uint256 claimedBalance = mockTokenA.balanceOf(user1);
        console.log("User1 claimed Token A balance:", claimedBalance - initialBalance);

        assertEq(balanceManager.balances(user1, address(mockTokenA)), 0, "Balance should be claimed");
        assertEq(claimedBalance, initialBalance + amount, "User1 should receive the claimed tokens");
        console.log("User1 final Token A balance:", claimedBalance);

        vm.stopPrank();
    }

    function testClaimAllBalances() public {
        vm.startPrank(admin1);

        balanceManager.setBalance(user1, address(mockTokenA), fiveHundred); // set token A balance to 500
        balanceManager.setBalance(user1, address(mockTokenC), threeHundred); // set token C balance to 300
        console.log("Token A balance for user1:", fiveHundred);
        console.log("Token C balance for user1:", threeHundred);

        vm.stopPrank();

        // Fund the contract with tokens
        vm.startPrank(user1);
        mockTokenA.approve(address(balanceManager), oneThousand); // approve for more than balance
        mockTokenC.approve(address(balanceManager), oneThousand);
        balanceManager.fund(address(mockTokenA), oneThousand); // fund for more than balance
        balanceManager.fund(address(mockTokenC), oneThousand);
        console.log("Funded contract with Token A:", oneThousand);
        console.log("Funded contract with Token C:", oneThousand);
        vm.stopPrank();

        // Check initial balances
        uint256 initialTokenABalance = mockTokenA.balanceOf(user1);
        uint256 initialTokenCBalance = mockTokenC.balanceOf(user1);
        console.log("Initial User1 Token A balance:", initialTokenABalance);
        console.log("Initial User1 Token C balance:", initialTokenCBalance);

        vm.startPrank(user1);
        balanceManager.claimAll();
        assertEq(balanceManager.balances(user1, address(mockTokenA)), 0, "Balance for Token A should be claimed");
        assertEq(balanceManager.balances(user1, address(mockTokenC)), 0, "Balance for Token C should be claimed");

        uint256 finalTokenABalance = mockTokenA.balanceOf(user1);
        uint256 finalTokenCBalance = mockTokenC.balanceOf(user1);
        console.log("Final User1 Token A balance:", finalTokenABalance);
        console.log("Final User1 Token C balance:", finalTokenCBalance);

        assertEq(finalTokenABalance, initialTokenABalance + fiveHundred, "User1 should receive the claimed Token A");
        assertEq(finalTokenCBalance, initialTokenCBalance + threeHundred, "User1 should receive the claimed Token C");
        console.log("User1 claimed all balances");

        vm.stopPrank();
    }

    function testWithdrawExcessTokens() public {
        // Set up initial balances
        vm.startPrank(admin1);

        uint256 userBalance = 500 * 10 ** 18;
        uint256 fundAmount = 500 * 10 ** 18;
        uint256 excessAmount = 500 * 10 ** 18;
        uint256 additionalAmount = 500 * 10 ** 18;
        uint256 totalAmount = fundAmount + additionalAmount;

        balanceManager.setBalance(user1, address(mockTokenA), userBalance);
        console.log("Set Token A balance for user1:", userBalance);

        vm.stopPrank();

        // User1 funds the contract with Token A
        vm.startPrank(user1);
        mockTokenA.approve(address(balanceManager), totalAmount);
        balanceManager.fund(address(mockTokenA), fundAmount);
        console.log("User1 funded contract with Token A:", fundAmount);
        vm.stopPrank();

        // Admin2 deposits additional funds to the contract
        vm.startPrank(admin2);
        mockTokenA.approve(address(balanceManager), additionalAmount);
        balanceManager.fund(address(mockTokenA), additionalAmount);
        console.log("Admin2 funded contract with additional Token A:", additionalAmount);
        vm.stopPrank();

        // Check initial balances before withdrawal
        uint256 initialAdmin1Balance = mockTokenA.balanceOf(admin1);
        uint256 initialContractBalance = mockTokenA.balanceOf(address(balanceManager));
        console.log("Initial Admin1 Token A balance:", initialAdmin1Balance);
        console.log("Initial contract Token A balance:", initialContractBalance);

        // Admin1 withdraws excess tokens
        vm.startPrank(admin1);
        balanceManager.withdrawExcessTokens(address(mockTokenA), excessAmount, admin1);
        console.log("Admin1 withdrew excess tokens:", excessAmount);
        vm.stopPrank();

        // Check final balances after withdrawal
        uint256 finalAdmin1Balance = mockTokenA.balanceOf(admin1);
        uint256 finalContractBalance = mockTokenA.balanceOf(address(balanceManager));
        uint256 finalUserBalance = balanceManager.balances(user1, address(mockTokenA));
        console.log("Final Admin1 Token A balance:", finalAdmin1Balance);
        console.log("Final contract Token A balance:", finalContractBalance);
        console.log("Final user1 Token A balance:", finalUserBalance);

        // Assert admin only withdrew extra tokens
        assertEq(finalAdmin1Balance, initialAdmin1Balance + excessAmount, "Admin1 should receive the excess tokens");

        // Assert user balance remains unchanged
        assertEq(finalUserBalance, userBalance, "User1 balance should remain unchanged");

        // Assert Token A in contract is still enough to cover user balance
        assertEq(finalContractBalance, userBalance, "Contract should still have enough Token A to cover user balance");
    }

    function testWithdrawExcessTokensThenClaim() public {
        // Set up initial balances
        vm.startPrank(admin1);

        uint256 userBalance = 500 * 10 ** 18;
        uint256 fundAmount = 500 * 10 ** 18;
        uint256 excessAmount = 500 * 10 ** 18;
        uint256 additionalAmount = 500 * 10 ** 18;
        uint256 totalAmount = fundAmount + additionalAmount;

        balanceManager.setBalance(user1, address(mockTokenA), userBalance);
        console.log("Set Token A balance for user1:", userBalance);

        vm.stopPrank();

        // User1 funds the contract with Token A
        vm.startPrank(user1);
        mockTokenA.approve(address(balanceManager), totalAmount);
        balanceManager.fund(address(mockTokenA), fundAmount);
        console.log("User1 funded contract with Token A:", fundAmount);
        vm.stopPrank();

        // Admin2 deposits additional funds to the contract
        vm.startPrank(admin2);
        mockTokenA.approve(address(balanceManager), additionalAmount);
        balanceManager.fund(address(mockTokenA), additionalAmount);
        console.log("Admin2 funded contract with additional Token A:", additionalAmount);
        vm.stopPrank();

        // Check initial balances before withdrawal
        uint256 initialAdmin1Balance = mockTokenA.balanceOf(admin1);
        uint256 initialContractBalance = mockTokenA.balanceOf(address(balanceManager));
        uint256 initialUser1Balance = mockTokenA.balanceOf(user1);
        console.log("Initial Admin1 Token A balance:", initialAdmin1Balance);
        console.log("Initial contract Token A balance:", initialContractBalance);
        console.log("Initial User1 Token A balance:", initialUser1Balance);

        // Admin1 withdraws excess tokens
        vm.startPrank(admin1);
        balanceManager.withdrawExcessTokens(address(mockTokenA), excessAmount, admin1);
        console.log("Admin1 withdrew excess tokens:", excessAmount);
        vm.stopPrank();

        // Check balances after withdrawal
        uint256 finalAdmin1Balance = mockTokenA.balanceOf(admin1);
        uint256 finalContractBalanceAfterWithdrawal = mockTokenA.balanceOf(address(balanceManager));
        console.log("Final Admin1 Token A balance after withdrawal:", finalAdmin1Balance);
        console.log("Final contract Token A balance after withdrawal:", finalContractBalanceAfterWithdrawal);

        // User1 claims their balance
        vm.startPrank(user1);
        balanceManager.claim(address(mockTokenA));
        uint256 finalUser1Balance = mockTokenA.balanceOf(user1);
        console.log("User1 claimed Token A balance:", userBalance);
        vm.stopPrank();

        // Final balances
        uint256 finalContractBalance = mockTokenA.balanceOf(address(balanceManager));
        console.log("Final contract Token A balance:", finalContractBalance);
        console.log("Final User1 Token A balance:", finalUser1Balance);

        // Assert admin only withdrew extra tokens
        assertEq(finalAdmin1Balance, initialAdmin1Balance + excessAmount, "Admin1 should receive the excess tokens");

        // Assert user balance was claimed correctly
        assertEq(finalUser1Balance, initialUser1Balance + userBalance, "User1 should receive the claimed tokens");

        // Assert Token A in contract is now zero after user's claim
        assertEq(finalContractBalance, 0, "Contract should have zero Token A after user's claim");
    }

    function testAdminFundsUserClaims() public {
        // Log initial user balance
        uint256 initialUser1Balance = mockTokenA.balanceOf(user1);
        console.log("Initial User1 Token A balance:", initialUser1Balance);

        // Admin1 funds the contract
        vm.startPrank(admin1);
        uint256 fundAmount = 1000 * 10 ** 18;
        mockTokenA.approve(address(balanceManager), fundAmount);
        balanceManager.fund(address(mockTokenA), fundAmount);
        console.log("Admin1 funded contract with Token A:", fundAmount);

        // Admin1 sets balance for User1
        uint256 userBalance = 500 * 10 ** 18;
        balanceManager.setBalance(user1, address(mockTokenA), userBalance);
        console.log("Admin1 set Token A balance for User1:", userBalance);

        vm.stopPrank();

        // User1 claims their balance
        vm.startPrank(user1);
        balanceManager.claim(address(mockTokenA));
        uint256 claimedBalance = mockTokenA.balanceOf(user1) - initialUser1Balance;
        console.log("User1 claimed Token A balance:", claimedBalance);

        vm.stopPrank();

        // Final user balance
        uint256 finalUser1Balance = mockTokenA.balanceOf(user1);
        console.log("Final User1 Token A balance:", finalUser1Balance);

        // Assertions
        assertEq(claimedBalance, userBalance, "User1 should receive the claimed balance");
        assertTrue(finalUser1Balance > initialUser1Balance, "User1 should have more tokens than initially");
    }

    // attempt to set balance for contract address
    function testCannotAddContractBalance() public {
        vm.startPrank(admin1);

        address contractAddress = address(balanceManager);
        vm.expectRevert("Contract cannot be the user");
        balanceManager.setBalance(contractAddress, address(mockTokenA), fiveHundred);

        vm.stopPrank();
    }

    // assert contract cannot receive ETH
    function testCannotReceiveEth() public {
        vm.expectRevert(bytes("Contract should not accept ETH"));
        (bool success,) = address(balanceManager).call{value: 1 ether}("");
        console.log("ETH transfer success status:", success);
        assertFalse(success, "Contract should not be able to accept ETH");
    }
}
