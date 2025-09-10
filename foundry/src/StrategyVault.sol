// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title StrategyVault
 * @dev An ERC4626 vault that allows users to deposit funds, receive vault tokens,
 * and enables an authorized agent to execute trading strategies according to
 * off-chain strategy parameters
 */
contract StrategyVault is ERC4626, AccessControl, ReentrancyGuard {
    using Math for uint256;

    bytes32 public constant AGENT_ROLE = keccak256("AGENT_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    bool public tradingEnabled = true;
    uint256 public lastRebalanceTimestamp;
    uint256 public minLiquidityRequired = 0; // Minimum amount to keep in vault for withdrawals
    uint256 public depositFee = 0; // Fee in basis points (e.g., 50 = 0.5%)
    uint256 public withdrawalFee = 0; // Fee in basis points
    uint256 public performanceFee = 0; // Fee in basis points
    address public feeRecipient;

    // Vault owner - can be updated with ownership transfer
    address public vaultOwner;

    // Map of strategy IDs to strategy references (could be IPFS hashes or other identifiers)
    // This doesn't store the actual strategy but just a reference to where it's stored off-chain
    mapping(uint256 => string) public strategyReferences;
    uint256 public currentStrategyId;

    // Events
    event StrategyExecuted(address indexed executor, address[] contracts, uint256 strategyId);
    event WithdrawalProcessed(address indexed user, uint256 shares, uint256 assets);
    event StrategyReferenceUpdated(uint256 strategyId, string referenceData);
    event CurrentStrategyChanged(uint256 strategyId);
    event TradingStatusChanged(bool enabled);
    event VaultOwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event DepositFeeUpdated(uint256 newFee);
    event WithdrawalFeeUpdated(uint256 newFee);
    event PerformanceFeeUpdated(uint256 newFee);
    event FeeRecipientUpdated(address newRecipient);
    event FeesCollected(uint256 amount);

    // Errors
    error TradingDisabled();
    error InvalidExecuteParams();
    error InvalidAddress();
    error ExecutionFailed();
    error InsufficientLiquidity();
    error UnauthorizedCaller();
    error InvalidStrategyId();
    error ZeroAmount();
    error FeeTooHigh();
    error InvalidFeeRecipient();
    error InsufficientFunds();

    /**
     * @dev Constructor that sets up the ERC4626 vault with the given asset token
     * @param _asset The underlying asset token address
     * @param _name The name of the vault token
     * @param _symbol The symbol of the vault token
     */
    constructor(IERC20 _asset, string memory _name, string memory _symbol) ERC4626(_asset) ERC20(_name, _symbol) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        vaultOwner = msg.sender;
        feeRecipient = msg.sender;

        lastRebalanceTimestamp = block.timestamp;
    }

    /**
     * @dev Deposit assets into the vault and receive vault tokens
     * @param assets Amount of assets to deposit
     * @param receiver Address to receive the vault tokens
     * @return shares Amount of vault tokens minted
     */
    function deposit(uint256 assets, address receiver) public override nonReentrant returns (uint256 shares) {
        if (assets == 0) revert ZeroAmount();

        // Calculate fee amount
        uint256 fee = (assets * depositFee) / 10000;
        uint256 assetsAfterFee = assets - fee;

        // Calculate shares
        shares = previewDeposit(assetsAfterFee);

        // Transfer assets from user to vault
        IERC20(asset()).transferFrom(msg.sender, address(this), assets);

        // If there's a fee, transfer it to the fee recipient
        if (fee > 0 && feeRecipient != address(0)) {
            IERC20(asset()).transfer(feeRecipient, fee);
            emit FeesCollected(fee);
        }

        // Mint vault tokens to receiver
        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    /**
     * @dev Execute a series of transactions as part of the trading strategy
     * Strategy logic is maintained off-chain by the agent
     * @param contracts Array of contract addresses to interact with
     * @param data Array of calldata to send to each contract
     * @param msgValues Array of ETH values to send with each transaction
     */
    function execute(address[] calldata contracts, bytes[] calldata data, uint256[] calldata msgValues)
        external
        onlyRole(AGENT_ROLE)
        nonReentrant
    {
        // Check if trading is enabled
        if (!tradingEnabled) revert TradingDisabled();

        // Validate parameters
        if (contracts.length != data.length || data.length != msgValues.length) {
            revert InvalidExecuteParams();
        }

        // Calculate total ETH value being sent
        uint256 totalValue = 0;
        for (uint256 i = 0; i < msgValues.length; i++) {
            totalValue += msgValues[i];
        }

        // Ensure we maintain minimum liquidity for withdrawals
        uint256 remainingBalance = address(this).balance - totalValue;
        if (remainingBalance < minLiquidityRequired) revert InsufficientLiquidity();

        // Execute each transaction
        for (uint256 i = 0; i < contracts.length; i++) {
            if (contracts[i] == address(0)) revert InvalidAddress();

            (bool success,) = contracts[i].call{value: msgValues[i]}(data[i]);
            if (!success) revert ExecutionFailed();
        }

        emit StrategyExecuted(msg.sender, contracts, currentStrategyId);
    }

    /**
     * @dev Withdraw assets directly without cooldown period
     * @param assets Amount of assets to withdraw
     * @param receiver Address to receive the assets
     * @param owner Owner of the shares
     * @return shares Amount of shares burned
     */
    function withdraw(uint256 assets, address receiver, address owner)
        public
        override
        nonReentrant
        returns (uint256 shares)
    {
        if (assets == 0) revert ZeroAmount();

        // Check if there are enough funds in the vault
        if (assets > IERC20(asset()).balanceOf(address(this))) {
            revert InsufficientFunds();
        }

        // Calculate shares needed
        shares = previewWithdraw(assets);

        // Check if caller has enough shares
        if (msg.sender != owner) {
            uint256 allowed = allowance(owner, msg.sender);
            if (allowed < shares) {
                revert ERC20InsufficientAllowance(msg.sender, allowed, shares);
            }
        }

        // Calculate withdrawal fee
        uint256 fee = (assets * withdrawalFee) / 10000;
        uint256 assetsAfterFee = assets - fee;

        // Burn shares
        _burn(owner, shares);

        // Transfer fee if applicable
        if (fee > 0 && feeRecipient != address(0)) {
            IERC20(asset()).transfer(feeRecipient, fee);
            emit FeesCollected(fee);
        }

        // Transfer remaining assets to receiver
        IERC20(asset()).transfer(receiver, assetsAfterFee);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);
        emit WithdrawalProcessed(owner, shares, assetsAfterFee);
    }

    /**
     * @dev Redeem shares directly without cooldown period
     * @param shares Amount of shares to redeem
     * @param receiver Address to receive the assets
     * @param owner Owner of the shares
     * @return assets Amount of assets returned
     */
    function redeem(uint256 shares, address receiver, address owner)
        public
        override
        nonReentrant
        returns (uint256 assets)
    {
        if (shares == 0) revert ZeroAmount();

        // Calculate assets to return based on current share price
        assets = previewRedeem(shares);

        // Check if there are enough funds in the vault
        if (assets > IERC20(asset()).balanceOf(address(this))) {
            revert InsufficientFunds();
        }

        // Check if caller has enough shares
        if (msg.sender != owner) {
            uint256 allowed = allowance(owner, msg.sender);
            if (allowed < shares) {
                revert ERC20InsufficientAllowance(msg.sender, allowed, shares);
            }
        }

        // Calculate withdrawal fee
        uint256 fee = (assets * withdrawalFee) / 10000;
        uint256 assetsAfterFee = assets - fee;

        // Burn shares
        _burn(owner, shares);

        // Transfer fee if applicable
        if (fee > 0 && feeRecipient != address(0)) {
            IERC20(asset()).transfer(feeRecipient, fee);
            emit FeesCollected(fee);
        }

        // Transfer remaining assets to receiver
        IERC20(asset()).transfer(receiver, assetsAfterFee);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);
        emit WithdrawalProcessed(owner, shares, assetsAfterFee);
    }

    /**
     * @dev Collect performance fees
     * Can be called periodically by admin or agent
     */
    function collectPerformanceFee() external nonReentrant {
        if (!hasRole(ADMIN_ROLE, msg.sender) && !hasRole(AGENT_ROLE, msg.sender)) {
            revert UnauthorizedCaller();
        }

        if (performanceFee == 0 || feeRecipient == address(0)) {
            return;
        }

        // Simple performance fee implementation - based on gains since last collection
        // In a production system, you would track high water marks, etc.
        uint256 totalValue = totalAssets();

        // Calculate fee
        uint256 fee = (totalValue * performanceFee) / 10000;

        if (fee > 0) {
            IERC20(asset()).transfer(feeRecipient, fee);
            emit FeesCollected(fee);
        }
    }

    /**
     * @dev Add or update a strategy reference (e.g., IPFS hash of the strategy JSON)
     * @param strategyId ID of the strategy
     * @param referenceData Off-chain reference to the strategy (IPFS hash, URL, etc.)
     */
    function setStrategyReference(uint256 strategyId, string calldata referenceData) external {
        if (msg.sender != vaultOwner && !hasRole(ADMIN_ROLE, msg.sender)) {
            revert UnauthorizedCaller();
        }

        strategyReferences[strategyId] = referenceData;
        emit StrategyReferenceUpdated(strategyId, referenceData);
    }

    /**
     * @dev Set the active strategy by ID
     * @param strategyId ID of the strategy to activate
     */
    function setCurrentStrategy(uint256 strategyId) external {
        if (msg.sender != vaultOwner && !hasRole(ADMIN_ROLE, msg.sender)) {
            revert UnauthorizedCaller();
        }

        // Make sure the strategy reference exists
        if (bytes(strategyReferences[strategyId]).length == 0) {
            revert InvalidStrategyId();
        }

        currentStrategyId = strategyId;
        emit CurrentStrategyChanged(strategyId);
    }

    /**
     * @dev Set the minimum liquidity to maintain in the vault
     * @param _minLiquidity Minimum liquidity amount
     */
    function setMinLiquidityRequired(uint256 _minLiquidity) external onlyRole(ADMIN_ROLE) {
        minLiquidityRequired = _minLiquidity;
    }

    /**
     * @dev Enable or disable trading
     * @param _enabled Whether trading should be enabled
     */
    function setTradingEnabled(bool _enabled) external onlyRole(ADMIN_ROLE) {
        tradingEnabled = _enabled;
        emit TradingStatusChanged(_enabled);
    }

    /**
     * @dev Set the deposit fee (in basis points)
     * @param _fee New fee in basis points (e.g., 50 = 0.5%)
     */
    function setDepositFee(uint256 _fee) external onlyRole(ADMIN_ROLE) {
        if (_fee > 1000) revert FeeTooHigh(); // Max 10%
        depositFee = _fee;
        emit DepositFeeUpdated(_fee);
    }

    /**
     * @dev Set the withdrawal fee (in basis points)
     * @param _fee New fee in basis points
     */
    function setWithdrawalFee(uint256 _fee) external onlyRole(ADMIN_ROLE) {
        if (_fee > 1000) revert FeeTooHigh(); // Max 10%
        withdrawalFee = _fee;
        emit WithdrawalFeeUpdated(_fee);
    }

    /**
     * @dev Set the performance fee (in basis points)
     * @param _fee New fee in basis points
     */
    function setPerformanceFee(uint256 _fee) external onlyRole(ADMIN_ROLE) {
        if (_fee > 3000) revert FeeTooHigh(); // Max 30%
        performanceFee = _fee;
        emit PerformanceFeeUpdated(_fee);
    }

    /**
     * @dev Set the fee recipient
     * @param _recipient New fee recipient address
     */
    function setFeeRecipient(address _recipient) external onlyRole(ADMIN_ROLE) {
        if (_recipient == address(0)) revert InvalidFeeRecipient();
        feeRecipient = _recipient;
        emit FeeRecipientUpdated(_recipient);
    }

    /**
     * @dev Transfer vault ownership
     * @param newOwner Address of the new owner
     */
    function transferVaultOwnership(address newOwner) external {
        if (msg.sender != vaultOwner) revert UnauthorizedCaller();
        if (newOwner == address(0)) revert InvalidAddress();

        address oldOwner = vaultOwner;
        vaultOwner = newOwner;
        emit VaultOwnershipTransferred(oldOwner, newOwner);
    }

    /**
     * @dev Add an agent address that can execute trading strategies
     * @param _agent Address to be granted the agent role
     */
    function addAgent(address _agent) external {
        if (msg.sender != vaultOwner && !hasRole(ADMIN_ROLE, msg.sender)) {
            revert UnauthorizedCaller();
        }
        _grantRole(AGENT_ROLE, _agent);
    }

    /**
     * @dev Remove an agent's trading privileges
     * @param _agent Address to have the agent role revoked
     */
    function removeAgent(address _agent) external {
        if (msg.sender != vaultOwner && !hasRole(ADMIN_ROLE, msg.sender)) {
            revert UnauthorizedCaller();
        }
        _revokeRole(AGENT_ROLE, _agent);
    }

    /**
     * @dev Handle tokens received through ERC20 transfers
     */
    function rescueTokens(address tokenAddress) external onlyRole(ADMIN_ROLE) {
        IERC20 token = IERC20(tokenAddress);
        uint256 balance = token.balanceOf(address(this));
        token.transfer(msg.sender, balance);
    }

    /**
     * @dev Required override for ERC4626 - returns the total assets managed by the vault
     * Note: In a production environment, this would need to track assets deployed
     * across various protocols
     */
    function totalAssets() public view override returns (uint256) {
        // This should be extended to include assets deployed in various protocols
        return IERC20(asset()).balanceOf(address(this));
    }

    /**
     * @dev Get the current strategy reference
     */
    function getCurrentStrategyReference() external view returns (string memory) {
        return strategyReferences[currentStrategyId];
    }

    /**
     * @dev Receive function to accept ETH
     */
    receive() external payable {}

    /**
     * @dev Fallback function
     */
    fallback() external payable {}
}
