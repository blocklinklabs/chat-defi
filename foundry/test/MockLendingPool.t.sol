// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {MockLendingPool} from "../src/MockLendingPool.sol";
import {MockToken} from "../src/MockToken.sol";

contract MockLendingPoolTest is Test {
    MockLendingPool public lendingPool;
    MockToken public token;

    address public owner = address(1);
    address public user1 = address(2);
    address public user2 = address(3);

    uint256 public constant INITIAL_SUPPLY = 1000000 * 1e18;
    uint256 public constant USER_INITIAL_BALANCE = 100000 * 1e18;
    uint256 public constant ANNUAL_INTEREST_RATE = 500; // 5% annual interest

    function setUp() public {
        vm.startPrank(owner);

        // Deploy mock token
        token = new MockToken("Test Token", "TEST", 18, 1000000);

        // Deploy lending pool
        lendingPool = new MockLendingPool(address(token), ANNUAL_INTEREST_RATE);

        // Fund users
        token.transfer(user1, USER_INITIAL_BALANCE);
        token.transfer(user2, USER_INITIAL_BALANCE);

        vm.stopPrank();

        // User1 approves lending pool to spend tokens
        vm.startPrank(user1);
        token.approve(address(lendingPool), type(uint256).max);
        vm.stopPrank();

        // User2 approves lending pool to spend tokens
        vm.startPrank(user2);
        token.approve(address(lendingPool), type(uint256).max);
        vm.stopPrank();
    }

    // ==== INITIALIZATION TESTS ====

    function testInitialState() public view {
        assertEq(address(lendingPool.token()), address(token));
        assertEq(lendingPool.annualInterestRate(), ANNUAL_INTEREST_RATE);
        assertEq(lendingPool.totalSupplied(), 0);
    }

    // ==== DEPOSIT TESTS ====

    function testDeposit() public {
        uint256 depositAmount = 1000 * 1e18;

        vm.startPrank(user1);
        uint256 balanceBefore = token.balanceOf(user1);
        lendingPool.deposit(depositAmount);
        uint256 balanceAfter = token.balanceOf(user1);
        vm.stopPrank();

        // Check token transfer
        assertEq(balanceBefore - balanceAfter, depositAmount);
        
        // Check user's supplied amount
        assertEq(lendingPool.userSupplied(user1), depositAmount);
        
        // Check total supplied
        assertEq(lendingPool.totalSupplied(), depositAmount);
    }

    function testDepositZeroAmount() public {
        vm.startPrank(user1);
        vm.expectRevert("Amount must be greater than zero");
        lendingPool.deposit(0);
        vm.stopPrank();
    }

    function testMultipleDeposits() public {
        uint256 firstDeposit = 1000 * 1e18;
        uint256 secondDeposit = 2000 * 1e18;

        vm.startPrank(user1);
        lendingPool.deposit(firstDeposit);
        lendingPool.deposit(secondDeposit);
        vm.stopPrank();

        // Check user's supplied amount
        assertEq(lendingPool.userSupplied(user1), firstDeposit + secondDeposit);
        
        // Check total supplied
        assertEq(lendingPool.totalSupplied(), firstDeposit + secondDeposit);
    }

    function testMultipleUsers() public {
        uint256 user1Deposit = 1000 * 1e18;
        uint256 user2Deposit = 2000 * 1e18;

        vm.prank(user1);
        lendingPool.deposit(user1Deposit);

        vm.prank(user2);
        lendingPool.deposit(user2Deposit);

        // Check individual supplied amounts
        assertEq(lendingPool.userSupplied(user1), user1Deposit);
        assertEq(lendingPool.userSupplied(user2), user2Deposit);
        
        // Check total supplied
        assertEq(lendingPool.totalSupplied(), user1Deposit + user2Deposit);
    }

    // ==== INTEREST TESTS ====

    function testInterestAccrual() public {
        uint256 depositAmount = 10000 * 1e18;

        // User deposits
        vm.prank(user1);
        lendingPool.deposit(depositAmount);

        // Initial interest should be zero
        assertEq(lendingPool.userInterest(user1), 0);

        // Advance time by 1 year
        vm.warp(block.timestamp + 365 days);

        // Accrue interest
        vm.prank(user1);
        lendingPool.accrueInterest();

        // Calculate expected interest
        uint256 expectedInterest = (depositAmount * ANNUAL_INTEREST_RATE) / 10000;

        // Check interest accrual
        assertEq(lendingPool.userInterest(user1), expectedInterest);
    }

    function testPartialYearInterest() public {
        uint256 depositAmount = 10000 * 1e18;

        // User deposits
        vm.prank(user1);
        lendingPool.deposit(depositAmount);

        // Advance time by 6 months
        vm.warp(block.timestamp + 182.5 days);

        // Accrue interest
        vm.prank(user1);
        lendingPool.accrueInterest();

        // Calculate expected interest (approximately half of the annual interest)
        uint256 expectedInterest = (depositAmount * ANNUAL_INTEREST_RATE * 182.5 days) / (365 days * 10000);

        // Check interest accrual with a small tolerance for rounding
        uint256 interest = lendingPool.userInterest(user1);
        assertApproxEqRel(interest, expectedInterest, 0.01e18); // 1% tolerance
    }

    function testGetAccruedInterest() public {
        uint256 depositAmount = 10000 * 1e18;

        // User deposits
        vm.prank(user1);
        lendingPool.deposit(depositAmount);

        // Advance time by 1 year
        vm.warp(block.timestamp + 365 days);

        // Get accrued interest without updating state
        uint256 accrued = lendingPool.getAccruedInterest(user1);
        
        // Calculate expected interest
        uint256 expectedInterest = (depositAmount * ANNUAL_INTEREST_RATE) / 10000;

        // Check interest calculation
        assertEq(accrued, expectedInterest);
        
        // Verify the state hasn't been updated
        assertEq(lendingPool.userInterest(user1), 0);
    }

    function testGetTotalBalance() public {
        uint256 depositAmount = 10000 * 1e18;

        // User deposits
        vm.prank(user1);
        lendingPool.deposit(depositAmount);

        // Advance time by 1 year
        vm.warp(block.timestamp + 365 days);

        // Get total balance
        uint256 totalBalance = lendingPool.getTotalBalance(user1);
        
        // Calculate expected interest
        uint256 expectedInterest = (depositAmount * ANNUAL_INTEREST_RATE) / 10000;
        uint256 expectedTotalBalance = depositAmount + expectedInterest;

        // Check total balance calculation
        assertEq(totalBalance, expectedTotalBalance);
    }

    // ==== WITHDRAW TESTS ====

    function testWithdraw() public {
        uint256 depositAmount = 10000 * 1e18;

        // User deposits
        vm.prank(user1);
        lendingPool.deposit(depositAmount);

        // Advance time by 1 year
        vm.warp(block.timestamp + 365 days);

        // Calculate expected interest
        uint256 expectedInterest = (depositAmount * ANNUAL_INTEREST_RATE) / 10000;

        // Withdraw half of the deposit
        uint256 withdrawAmount = depositAmount / 2;
        uint256 balanceBefore = token.balanceOf(user1);
        
        vm.prank(user1);
        lendingPool.withdraw(withdrawAmount);
        
        uint256 balanceAfter = token.balanceOf(user1);

        // Calculate expected interest for withdrawn amount
        uint256 expectedWithdrawnInterest = (withdrawAmount * expectedInterest) / depositAmount;
        uint256 expectedTransfer = withdrawAmount + expectedWithdrawnInterest;

        // Check token transfer
        assertEq(balanceAfter - balanceBefore, expectedTransfer);
        
        // Check updated supplied amount
        assertEq(lendingPool.userSupplied(user1), depositAmount - withdrawAmount);
        
        // Check updated total supplied
        assertEq(lendingPool.totalSupplied(), depositAmount - withdrawAmount);
        
        // Check remaining interest
        uint256 remainingInterest = expectedInterest - expectedWithdrawnInterest;
        assertApproxEqRel(lendingPool.userInterest(user1), remainingInterest, 0.01e18); // 1% tolerance
    }

    function testWithdrawZeroAmount() public {
        // User deposits
        vm.prank(user1);
        lendingPool.deposit(1000 * 1e18);

        // Try to withdraw zero
        vm.prank(user1);
        vm.expectRevert("Amount must be greater than zero");
        lendingPool.withdraw(0);
    }

    function testWithdrawInsufficientBalance() public {
        uint256 depositAmount = 1000 * 1e18;

        // User deposits
        vm.prank(user1);
        lendingPool.deposit(depositAmount);

        // Try to withdraw more than deposited
        vm.prank(user1);
        vm.expectRevert("Insufficient supplied balance");
        lendingPool.withdraw(depositAmount + 1);
    }

    function testWithdrawAll() public {
        uint256 depositAmount = 10000 * 1e18;

        // User deposits
        vm.prank(user1);
        lendingPool.deposit(depositAmount);

        // Advance time by 1 year
        vm.warp(block.timestamp + 365 days);

        // Ensure the pool has enough tokens to pay interest by minting additional tokens
        uint256 expectedInterest = (depositAmount * ANNUAL_INTEREST_RATE) / 10000;
        vm.startPrank(owner);
        token.mint(address(lendingPool), expectedInterest);
        vm.stopPrank();

        // Withdraw everything
        uint256 balanceBefore = token.balanceOf(user1);
        
        vm.prank(user1);
        lendingPool.withdraw(depositAmount);
        
        uint256 balanceAfter = token.balanceOf(user1);

        // Check token transfer
        uint256 expectedTotalWithdraw = depositAmount + expectedInterest;
        assertEq(balanceAfter - balanceBefore, expectedTotalWithdraw);
        
        // Check supplied amount is zero
        assertEq(lendingPool.userSupplied(user1), 0);
        
        // Check interest is zero
        assertEq(lendingPool.userInterest(user1), 0);
    }

    // ==== ADMIN FUNCTIONS TESTS ====

    function testUpdateInterestRate() public {
        uint256 newRate = 1000; // 10% annual interest

        // Initial rate
        assertEq(lendingPool.annualInterestRate(), ANNUAL_INTEREST_RATE);

        // Update rate
        vm.prank(owner);
        lendingPool.updateInterestRate(newRate);

        // Check updated rate
        assertEq(lendingPool.annualInterestRate(), newRate);
    }

    function testUpdateInterestRateUnauthorized() public {
        vm.prank(user1);
        vm.expectRevert();
        lendingPool.updateInterestRate(1000);
    }

    function testUpdateInterestRateTooHigh() public {
        vm.prank(owner);
        vm.expectRevert("Interest rate cannot exceed 100%");
        lendingPool.updateInterestRate(10001);
    }

    function testInterestRateChangeEffect() public {
        uint256 depositAmount = 10000 * 1e18;
        uint256 newRate = 1000; // 10% annual interest

        // User deposits
        vm.prank(user1);
        lendingPool.deposit(depositAmount);

        // Advance time by 6 months
        vm.warp(block.timestamp + 182.5 days);

        // Accrue interest for first 6 months
        vm.prank(user1);
        lendingPool.accrueInterest();

        // Calculate expected interest for first 6 months
        uint256 firstHalfInterest = (depositAmount * ANNUAL_INTEREST_RATE * 182.5 days) / (365 days * 10000);

        // Update interest rate
        vm.prank(owner);
        lendingPool.updateInterestRate(newRate);

        // Advance time by another 6 months
        vm.warp(block.timestamp + 182.5 days);

        // Accrue interest for second 6 months
        vm.prank(user1);
        lendingPool.accrueInterest();

        // Calculate expected interest for second 6 months
        uint256 secondHalfInterest = (depositAmount * newRate * 182.5 days) / (365 days * 10000);
        
        // Total expected interest
        uint256 totalExpectedInterest = firstHalfInterest + secondHalfInterest;

        // Check interest accrual
        uint256 actualInterest = lendingPool.userInterest(user1);
        assertApproxEqRel(actualInterest, totalExpectedInterest, 0.01e18); // 1% tolerance
    }
} 