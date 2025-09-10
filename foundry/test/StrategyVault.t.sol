// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {StrategyVault} from "../src/StrategyVault.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Mock ERC20 token for testing
contract MockToken is ERC20 {
    constructor() ERC20("Mock Token", "MOCK") {
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract StrategyVaultTest is Test {
    StrategyVault public vault;
    MockToken public token;

    address public admin = address(1);
    address public agent = address(2);
    address public user1 = address(3);
    address public user2 = address(4);
    address public feeRecipient = address(5);

    uint256 public constant INITIAL_DEPOSIT = 10000 * 1e18;

    // Test admin role hash
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant AGENT_ROLE = keccak256("AGENT_ROLE");

    function setUp() public {
        vm.startPrank(admin);

        // Deploy mock token
        token = new MockToken();

        // Deploy vault
        vault = new StrategyVault(token, "Vault Token", "vTKN");

        // Setup roles
        vault.grantRole(AGENT_ROLE, agent);

        // Setup fees
        vault.setDepositFee(50); // 0.5%
        vault.setWithdrawalFee(100); // 1%
        vault.setPerformanceFee(1000); // 10%
        vault.setFeeRecipient(feeRecipient);

        // Setup strategy reference
        vault.setStrategyReference(1, "ipfs://QmStrategy1");
        vault.setCurrentStrategy(1);

        // Fund users
        token.transfer(user1, 100000 * 1e18);
        token.transfer(user2, 100000 * 1e18);

        vm.stopPrank();

        // User1 approves vault to spend tokens
        vm.startPrank(user1);
        token.approve(address(vault), type(uint256).max);
        vm.stopPrank();

        // User2 approves vault to spend tokens
        vm.startPrank(user2);
        token.approve(address(vault), type(uint256).max);
        vm.stopPrank();
    }

    // ==== INITIALIZATION TESTS ====

    function testInitialState() public view {
        assertEq(address(vault.asset()), address(token));
        assertEq(vault.name(), "Vault Token");
        assertEq(vault.symbol(), "vTKN");
        assertEq(vault.depositFee(), 50);
        assertEq(vault.withdrawalFee(), 100);
        assertEq(vault.performanceFee(), 1000);
        assertEq(vault.feeRecipient(), feeRecipient);
        assertEq(vault.vaultOwner(), admin);
        assertTrue(vault.tradingEnabled());
        assertEq(vault.currentStrategyId(), 1);
        assertEq(vault.getCurrentStrategyReference(), "ipfs://QmStrategy1");
    }

    function testRoles() public view {
        assertTrue(vault.hasRole(ADMIN_ROLE, admin));
        assertTrue(vault.hasRole(AGENT_ROLE, agent));
    }

    // ==== DEPOSIT TESTS ====

    function testDeposit() public {
        uint256 depositAmount = 1000 * 1e18;

        vm.startPrank(user1);
        uint256 sharesBefore = vault.balanceOf(user1);
        uint256 shares = vault.deposit(depositAmount, user1);
        uint256 sharesAfter = vault.balanceOf(user1);
        vm.stopPrank();

        // Check shares were minted correctly
        assertEq(sharesAfter - sharesBefore, shares);

        // Check fees were collected
        uint256 expectedFee = (depositAmount * 50) / 10000; // 0.5%
        uint256 expectedAssets = depositAmount - expectedFee;

        // Verify fee transfer to recipient
        assertEq(token.balanceOf(feeRecipient), expectedFee);

        // Verify total assets in vault
        assertEq(vault.totalAssets(), expectedAssets);
    }

    function testDepositZeroAmount() public {
        vm.startPrank(user1);
        vm.expectRevert(StrategyVault.ZeroAmount.selector);
        vault.deposit(0, user1);
        vm.stopPrank();
    }

    function testDepositMultipleUsers() public {
        uint256 user1DepositAmount = 1000 * 1e18;
        uint256 user2DepositAmount = 2000 * 1e18;

        // User 1 deposits
        vm.startPrank(user1);
        uint256 user1Shares = vault.deposit(user1DepositAmount, user1);
        vm.stopPrank();

        // User 2 deposits
        vm.startPrank(user2);
        uint256 user2Shares = vault.deposit(user2DepositAmount, user2);
        vm.stopPrank();

        // Check correct share distribution
        assertEq(vault.balanceOf(user1), user1Shares);
        assertEq(vault.balanceOf(user2), user2Shares);

        // User2 should have approximately 2x the shares of user1
        // (Not exactly 2x due to fees)
        assertTrue(user2Shares > user1Shares * 195 / 100); // ~2x with some room for rounding
        assertTrue(user2Shares < user1Shares * 205 / 100); // ~2x with some room for rounding
    }

    // ==== WITHDRAW TESTS ====

    function testWithdraw() public {
        // Setup - user deposits
        uint256 depositAmount = 1000 * 1e18;

        vm.startPrank(user1);
        uint256 shares = vault.deposit(depositAmount, user1);

        // Calculate expected withdraw amount with fees
        uint256 depositFee = (depositAmount * 50) / 10000; // 0.5%
        uint256 assetsInVault = depositAmount - depositFee;
        uint256 withdrawalFee = (assetsInVault * 100) / 10000; // 1%
        uint256 expectedWithdrawAmount = assetsInVault - withdrawalFee;

        // Record balances before withdrawal
        uint256 tokenBalanceBefore = token.balanceOf(user1);

        // Withdraw all shares
        uint256 sharesWithdrawn = vault.withdraw(assetsInVault, user1, user1);
        uint256 tokenBalanceAfter = token.balanceOf(user1);
        vm.stopPrank();

        // Verify shares were burned
        assertEq(sharesWithdrawn, shares);
        assertEq(vault.balanceOf(user1), 0);

        // Verify withdrawal amount
        assertEq(tokenBalanceAfter - tokenBalanceBefore, expectedWithdrawAmount);

        // Verify fee transfer to recipient
        assertEq(token.balanceOf(feeRecipient), depositFee + withdrawalFee);
    }

    function testRedeem() public {
        // Setup - user deposits
        uint256 depositAmount = 1000 * 1e18;

        vm.startPrank(user1);
        uint256 shares = vault.deposit(depositAmount, user1);

        // Record balances before redemption
        uint256 tokenBalanceBefore = token.balanceOf(user1);

        // Redeem all shares
        uint256 assetsRedeemed = vault.redeem(shares, user1, user1);
        uint256 tokenBalanceAfter = token.balanceOf(user1);
        vm.stopPrank();

        // Verify shares were burned
        assertEq(vault.balanceOf(user1), 0);

        // Calculate expected redeem amount with fees
        uint256 depositFee = (depositAmount * 50) / 10000; // 0.5%
        uint256 assetsInVault = depositAmount - depositFee;
        uint256 withdrawalFee = (assetsInVault * 100) / 10000; // 1%
        uint256 expectedRedeemAmount = assetsInVault - withdrawalFee;

        // Verify redemption amount
        assertEq(tokenBalanceAfter - tokenBalanceBefore, expectedRedeemAmount);
        assertEq(assetsRedeemed, assetsInVault); // This is pre-fee amount

        // Verify fee transfer to recipient
        assertEq(token.balanceOf(feeRecipient), depositFee + withdrawalFee);
    }

    function testWithdrawInsufficientFunds() public {
        // User deposits
        uint256 depositAmount = 1000 * 1e18;

        vm.startPrank(user1);
        vault.deposit(depositAmount, user1);

        // Try to withdraw more than deposited
        vm.expectRevert(StrategyVault.InsufficientFunds.selector);
        vault.withdraw(depositAmount * 2, user1, user1);
        vm.stopPrank();
    }

    function testWithdrawZeroAmount() public {
        vm.startPrank(user1);
        vm.expectRevert(StrategyVault.ZeroAmount.selector);
        vault.withdraw(0, user1, user1);
        vm.stopPrank();
    }

    // ==== STRATEGY EXECUTION TESTS ====

    function testExecuteStrategy() public {
        // Setup a mock contract to receive strategy execution calls
        MockReceiver mockReceiver = new MockReceiver();

        // Fund the vault with ETH for execution
        vm.deal(address(vault), 10 ether);

        // Prepare execution parameters
        address[] memory contracts = new address[](1);
        bytes[] memory data = new bytes[](1);
        uint256[] memory msgValues = new uint256[](1);

        contracts[0] = address(mockReceiver);
        data[0] = abi.encodeWithSignature("receiveCall(uint256)", 123);
        msgValues[0] = 1 ether;

        // Execute strategy as agent
        vm.startPrank(agent);
        vault.execute(contracts, data, msgValues);
        vm.stopPrank();

        // Verify the call was received
        assertTrue(mockReceiver.called());
        assertEq(mockReceiver.lastValue(), 123);
        assertEq(address(mockReceiver).balance, 1 ether);
    }

    function testExecuteStrategyTradingDisabled() public {
        // Disable trading
        vm.startPrank(admin);
        vault.setTradingEnabled(false);
        vm.stopPrank();

        // Prepare execution parameters
        address[] memory contracts = new address[](1);
        bytes[] memory data = new bytes[](1);
        uint256[] memory msgValues = new uint256[](1);

        // Try to execute strategy
        vm.startPrank(agent);
        vm.expectRevert(StrategyVault.TradingDisabled.selector);
        vault.execute(contracts, data, msgValues);
        vm.stopPrank();
    }

    function testExecuteStrategyUnauthorized() public {
        // Prepare execution parameters
        address[] memory contracts = new address[](1);
        bytes[] memory data = new bytes[](1);
        uint256[] memory msgValues = new uint256[](1);

        // Try to execute strategy as unauthorized user
        vm.startPrank(user1);
        vm.expectRevert(); // AccessControl error
        vault.execute(contracts, data, msgValues);
        vm.stopPrank();
    }

    function testExecuteStrategyInvalidParams() public {
        // Prepare invalid execution parameters (mismatched arrays)
        address[] memory contracts = new address[](2);
        bytes[] memory data = new bytes[](1);
        uint256[] memory msgValues = new uint256[](1);

        contracts[0] = address(1);
        contracts[1] = address(2);
        data[0] = "";
        msgValues[0] = 0;

        // Try to execute strategy with invalid params
        vm.startPrank(agent);
        vm.expectRevert(StrategyVault.InvalidExecuteParams.selector);
        vault.execute(contracts, data, msgValues);
        vm.stopPrank();
    }

    function testExecuteStrategyInsufficientLiquidity() public {
        // Fund the vault with ETH
        vm.deal(address(vault), 1 ether);

        // Set minimum liquidity requirement
        vm.startPrank(admin);
        vault.setMinLiquidityRequired(0.5 ether);
        vm.stopPrank();

        // Prepare execution parameters that would consume too much ETH
        address[] memory contracts = new address[](1);
        bytes[] memory data = new bytes[](1);
        uint256[] memory msgValues = new uint256[](1);

        contracts[0] = address(1);
        data[0] = "";
        msgValues[0] = 0.6 ether; // This exceeds the allowed amount

        // Try to execute strategy
        vm.startPrank(agent);
        vm.expectRevert(StrategyVault.InsufficientLiquidity.selector);
        vault.execute(contracts, data, msgValues);
        vm.stopPrank();
    }

    // ==== FEE TESTS ====

    function testPerformanceFee() public {
        // Setup - user deposits
        uint256 depositAmount = 10000 * 1e18;

        vm.startPrank(user1);
        vault.deposit(depositAmount, user1);
        vm.stopPrank();

        // Simulate profit by directly sending tokens to the vault
        uint256 profit = 1000 * 1e18;
        token.mint(address(vault), profit);

        // Collect performance fee
        uint256 feeRecipientBalanceBefore = token.balanceOf(feeRecipient);

        vm.startPrank(admin);
        vault.collectPerformanceFee();
        vm.stopPrank();

        uint256 feeRecipientBalanceAfter = token.balanceOf(feeRecipient);

        // Calculate expected fee (10% of total assets)
        uint256 depositFee = (depositAmount * 50) / 10000; // 0.5%
        uint256 totalAssets = depositAmount - depositFee + profit;
        uint256 expectedPerformanceFee = (totalAssets * 1000) / 10000; // 10%

        // Verify performance fee
        assertEq(feeRecipientBalanceAfter - feeRecipientBalanceBefore, expectedPerformanceFee);
    }

    function testUpdateFees() public {
        vm.startPrank(admin);

        // Update fees
        vault.setDepositFee(100); // 1%
        vault.setWithdrawalFee(200); // 2%
        vault.setPerformanceFee(2000); // 20%

        vm.stopPrank();

        // Verify fee updates
        assertEq(vault.depositFee(), 100);
        assertEq(vault.withdrawalFee(), 200);
        assertEq(vault.performanceFee(), 2000);

        // Test fee too high reverts
        vm.startPrank(admin);
        vm.expectRevert(StrategyVault.FeeTooHigh.selector);
        vault.setDepositFee(1100); // 11% - over limit

        vm.expectRevert(StrategyVault.FeeTooHigh.selector);
        vault.setWithdrawalFee(1100); // 11% - over limit

        vm.expectRevert(StrategyVault.FeeTooHigh.selector);
        vault.setPerformanceFee(3100); // 31% - over limit
        vm.stopPrank();
    }

    // ==== ACCESS CONTROL TESTS ====

    function testAddRemoveAgent() public {
        address newAgent = address(10);

        // Add agent
        vm.startPrank(admin);
        vault.addAgent(newAgent);
        vm.stopPrank();

        // Verify agent role
        assertTrue(vault.hasRole(AGENT_ROLE, newAgent));

        // Remove agent
        vm.startPrank(admin);
        vault.removeAgent(newAgent);
        vm.stopPrank();

        // Verify agent role removed
        assertFalse(vault.hasRole(AGENT_ROLE, newAgent));
    }

    function testVaultOwnerTransfer() public {
        address newOwner = address(10);

        // Transfer ownership
        vm.startPrank(admin);
        vault.transferVaultOwnership(newOwner);
        vm.stopPrank();

        // Verify new owner
        assertEq(vault.vaultOwner(), newOwner);

        // Verify new owner can perform owner-only operations
        vm.startPrank(newOwner);
        address newerAgent = address(11);
        vault.addAgent(newerAgent);
        vm.stopPrank();

        // Verify agent was added
        assertTrue(vault.hasRole(AGENT_ROLE, newerAgent));
    }

    function testUnauthorizedVaultOwnerTransfer() public {
        address newOwner = address(10);

        // Try to transfer ownership as non-owner
        vm.startPrank(user1);
        vm.expectRevert(StrategyVault.UnauthorizedCaller.selector);
        vault.transferVaultOwnership(newOwner);
        vm.stopPrank();
    }

    // ==== STRATEGY REFERENCE TESTS ====

    function testSetStrategyReference() public {
        uint256 newStrategyId = 2;
        string memory newReference = "ipfs://QmStrategy2";

        // Set new strategy reference
        vm.startPrank(admin);
        vault.setStrategyReference(newStrategyId, newReference);
        vm.stopPrank();

        // Set current strategy to the new one
        vm.startPrank(admin);
        vault.setCurrentStrategy(newStrategyId);
        vm.stopPrank();

        // Verify current strategy
        assertEq(vault.currentStrategyId(), newStrategyId);
        assertEq(vault.getCurrentStrategyReference(), newReference);
    }

    function testSetInvalidStrategy() public {
        uint256 invalidStrategyId = 999;

        // Try to set current strategy to invalid ID
        vm.startPrank(admin);
        vm.expectRevert(StrategyVault.InvalidStrategyId.selector);
        vault.setCurrentStrategy(invalidStrategyId);
        vm.stopPrank();
    }

    // ==== UTILITY FUNCTIONS ====

    function testRescueTokens() public {
        // Send tokens directly to vault by minting them
        token.mint(address(vault), 1000 * 1e18);

        // Rescue tokens
        uint256 adminBalanceBefore = token.balanceOf(admin);

        vm.startPrank(admin);
        vault.rescueTokens(address(token));
        vm.stopPrank();

        uint256 adminBalanceAfter = token.balanceOf(admin);

        // Verify tokens were rescued
        assertEq(adminBalanceAfter - adminBalanceBefore, 1000 * 1e18);
    }

    function testReceiveEth() public {
        // Send ETH to vault
        vm.deal(address(this), 1 ether);
        (bool success,) = address(vault).call{value: 1 ether}("");

        // Verify ETH was received
        assertTrue(success);
        assertEq(address(vault).balance, 1 ether);
    }
}

// Mock receiver contract for testing strategy execution
contract MockReceiver {
    bool public called;
    uint256 public lastValue;

    function receiveCall(uint256 value) external payable {
        called = true;
        lastValue = value;
    }

    receive() external payable {}
}
