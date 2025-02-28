// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/BalanceManager.sol";
import "openzeppelin-contracts/token/ERC20/IERC20.sol";

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

    function testGetterMethods() public {
        vm.startPrank(admin1);

        uint256 amountA = 500 * 10 ** 18;
        uint256 amountC = 300 * 10 ** 18;
        uint256 amountB = 200 * 10 ** 18;
        balanceManager.setBalance(user1, address(mockTokenA), amountA);
        balanceManager.setBalance(user1, address(mockTokenC), amountC);
        balanceManager.setBalance(user2, address(mockTokenB), amountB);
        balanceManager.setBalance(user2, address(mockTokenC), amountC);
        console.log("User1 - Set Token A balance:", amountA);
        console.log("User1 - Set Token C balance:", amountC);
        console.log("User2 - Set Token B balance:", amountB);
        console.log("User2 - Set Token C balance:", amountC);

        vm.stopPrank();

        // Test getBalance
        uint256 balanceA = balanceManager.getBalance(user1, address(mockTokenA));
        uint256 balanceC1 = balanceManager.getBalance(user1, address(mockTokenC));
        uint256 balanceB = balanceManager.getBalance(user2, address(mockTokenB));
        uint256 balanceC2 = balanceManager.getBalance(user2, address(mockTokenC));
        assertEq(balanceA, amountA, "Getter method getBalance should return correct balance for Token A");
        assertEq(balanceC1, amountC, "Getter method getBalance should return correct balance for Token C for user1");
        assertEq(balanceB, amountB, "Getter method getBalance should return correct balance for Token B");
        assertEq(balanceC2, amountC, "Getter method getBalance should return correct balance for Token C for user2");
        console.log("User1 - getBalance balanceA:", balanceA);
        console.log("User1 - getBalance balanceC:", balanceC1);
        console.log("User2 - getBalance balanceB:", balanceB);
        console.log("User2 - getBalance balanceC:", balanceC2);

        // Test getBalancesForWallet
        (address[] memory tokens1, uint256[] memory balances1) = balanceManager.getBalancesForWallet(user1);
        console.log("User1 - getBalancesForWallet token1:", tokens1[0], ", balance1:", balances1[0]);
        console.log("User1 - getBalancesForWallet token2:", tokens1[1], ", balance2:", balances1[1]);
        assertEq(tokens1[0], address(mockTokenA), "First token for user1 should be Token A");
        assertEq(tokens1[1], address(mockTokenC), "Second token for user1 should be Token C");
        assertEq(balances1[0], amountA, "First balance for user1 should match Token A balance");
        assertEq(balances1[1], amountC, "Second balance for user1 should match Token C balance");

        (address[] memory tokens2, uint256[] memory balances2) = balanceManager.getBalancesForWallet(user2);
        console.log("User2 - getBalancesForWallet token1:", tokens2[0], ", balance1:", balances2[0]);
        console.log("User2 - getBalancesForWallet token2:", tokens2[1], ", balance2:", balances2[1]);
        assertEq(tokens2[0], address(mockTokenB), "First token for user2 should be Token B");
        assertEq(tokens2[1], address(mockTokenC), "Second token for user2 should be Token C");
        assertEq(balances2[0], amountB, "First balance for user2 should match Token B balance");
        assertEq(balances2[1], amountC, "Second balance for user2 should match Token C balance");

        // Test getBalancesForToken
        (address[] memory walletsA, uint256[] memory tokenBalancesA) =
            balanceManager.getBalancesForToken(address(mockTokenA));
        console.log("Token A - getBalancesForToken wallet1:", walletsA[0], ", balance1:", tokenBalancesA[0]);
        assertEq(walletsA[0], user1, "First wallet for Token A should be user1");
        assertEq(tokenBalancesA[0], amountA, "Balance for user1 with Token A should match");

        (address[] memory walletsB, uint256[] memory tokenBalancesB) =
            balanceManager.getBalancesForToken(address(mockTokenB));
        console.log("Token B - getBalancesForToken wallet1:", walletsB[0], ", balance1:", tokenBalancesB[0]);
        assertEq(walletsB[0], user2, "First wallet for Token B should be user2");
        assertEq(tokenBalancesB[0], amountB, "Balance for user2 with Token B should match");

        (address[] memory walletsC, uint256[] memory tokenBalancesC) =
            balanceManager.getBalancesForToken(address(mockTokenC));
        console.log("Token C - getBalancesForToken wallet1:", walletsC[0], ", balance1:", tokenBalancesC[0]);
        console.log("Token C - getBalancesForToken wallet2:", walletsC[1], ", balance2:", tokenBalancesC[1]);
        assertEq(walletsC[0], user1, "First wallet for Token C should be user1");
        assertEq(walletsC[1], user2, "Second wallet for Token C should be user2");
        assertEq(tokenBalancesC[0], amountC, "Balance for user1 with Token C should match");
        assertEq(tokenBalancesC[1], amountC, "Balance for user2 with Token C should match");

        // Test getAllTotalBalances
        (address[] memory allTokens, uint256[] memory totalBalances) = balanceManager.getAllTotalBalances();
        console.log("getAllTotalBalances token1:", allTokens[0], ", total balance1:", totalBalances[0]);
        console.log("getAllTotalBalances token2:", allTokens[1], ", total balance2:", totalBalances[1]);
        console.log("getAllTotalBalances token3:", allTokens[2], ", total balance3:", totalBalances[2]);
        assertEq(allTokens[0], address(mockTokenA), "First token in allTokens should be Token A");
        assertEq(totalBalances[0], amountA, "Total balance for Token A should match");
        assertEq(allTokens[1], address(mockTokenC), "Second token in allTokens should be Token C");
        assertEq(totalBalances[1], amountC * 2, "Total balance for Token C should match"); // amountC for user1 and user2
        assertEq(allTokens[2], address(mockTokenB), "Third token in allTokens should be Token B");
        assertEq(totalBalances[2], amountB, "Total balance for Token B should match");

        // Test getAllAdmins
        address[] memory admins = balanceManager.getAllAdmins();
        console.log("getAllAdmins admin1:", admins[0]);
        console.log("getAllAdmins admin2:", admins[1]);
        assertEq(admins[0], admin1, "First admin should be admin1");
        assertEq(admins[1], admin2, "Second admin should be admin2");

        // Test isAdmin
        bool isAdmin1 = balanceManager.isAdmin(admin1);
        bool isAdmin2 = balanceManager.isAdmin(admin2);
        bool isAdmin3 = balanceManager.isAdmin(user1); // should be false
        assertTrue(isAdmin1, "Admin1 should be recognized as admin");
        assertTrue(isAdmin2, "Admin2 should be recognized as admin");
        assertFalse(isAdmin3, "User1 should not be recognized as admin");

        // Test getTokensForUser
        address[] memory user1Tokens = balanceManager.getTokensForUser(user1);
        console.log("getTokensForUser for user1 token1:", user1Tokens[0]);
        console.log("getTokensForUser for user1 token2:", user1Tokens[1]);
        assertEq(user1Tokens[0], address(mockTokenA), "User1 should have Token A");
        assertEq(user1Tokens[1], address(mockTokenC), "User1 should have Token C");

        address[] memory user2Tokens = balanceManager.getTokensForUser(user2);
        console.log("getTokensForUser for user2 token1:", user2Tokens[0]);
        console.log("getTokensForUser for user2 token2:", user2Tokens[1]);
        assertEq(user2Tokens[0], address(mockTokenB), "User2 should have Token B");
        assertEq(user2Tokens[1], address(mockTokenC), "User2 should have Token C");

        // Test getUsersForToken
        address[] memory tokenAUsers = balanceManager.getUsersForToken(address(mockTokenA));
        console.log("getUsersForToken for Token A user1:", tokenAUsers[0]);
        assertEq(tokenAUsers[0], user1, "Token A should be associated with user1");

        address[] memory tokenBUsers = balanceManager.getUsersForToken(address(mockTokenB));
        console.log("getUsersForToken for Token B user1:", tokenBUsers[0]);
        assertEq(tokenBUsers[0], user2, "Token B should be associated with user2");

        address[] memory tokenCUsers = balanceManager.getUsersForToken(address(mockTokenC));
        console.log("getUsersForToken for Token C user1:", tokenCUsers[0]);
        console.log("getUsersForToken for Token C user2:", tokenCUsers[1]);
        assertEq(tokenCUsers[0], user1, "Token C should be associated with user1");
        assertEq(tokenCUsers[1], user2, "Token C should be associated with user2");
    }
}
