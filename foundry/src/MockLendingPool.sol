// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MockLendingPool
 * @dev A simple mock lending pool that accepts deposits of a specific token and provides yield
 */
contract MockLendingPool is ReentrancyGuard, Ownable {
    // The token used for the lending pool
    IERC20 public immutable token;
    
    // The annual interest rate in basis points (e.g., 500 = 5%)
    uint256 public annualInterestRate;
    
    // Timestamp of the last interest accrual
    uint256 public lastAccrualTimestamp;
    
    // Total supplied amount
    uint256 public totalSupplied;
    
    // Mapping of user address to their supplied amount
    mapping(address => uint256) public userSupplied;
    
    // Mapping of user address to their accrued interest
    mapping(address => uint256) public userInterest;
    
    // Events
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount, uint256 interest);
    event InterestRateUpdated(uint256 newRate);
    event InterestAccrued(address indexed user, uint256 interestAmount);
    
    /**
     * @dev Constructor to initialize the lending pool with a token and an interest rate
     * @param _token The ERC20 token for the lending pool
     * @param _annualInterestRate The annual interest rate in basis points (e.g., 500 = 5%)
     */
    constructor(address _token, uint256 _annualInterestRate) Ownable(msg.sender) {
        require(_token != address(0), "Token address cannot be zero");
        require(_annualInterestRate <= 10000, "Interest rate cannot exceed 100%");
        
        token = IERC20(_token);
        annualInterestRate = _annualInterestRate;
        lastAccrualTimestamp = block.timestamp;
    }
    
    /**
     * @dev Allows users to deposit tokens into the lending pool
     * @param amount The amount of tokens to deposit
     */
    function deposit(uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must be greater than zero");
        
        // Accrue interest first
        _accrueInterest();
        
        // Transfer tokens from user to the pool
        require(token.transferFrom(msg.sender, address(this), amount), "Token transfer failed");
        
        // Update user's supplied amount
        userSupplied[msg.sender] += amount;
        totalSupplied += amount;
        
        emit Deposit(msg.sender, amount);
    }
    
    /**
     * @dev Allows users to withdraw tokens along with accrued interest
     * @param amount The amount of tokens to withdraw
     */
    function withdraw(uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must be greater than zero");
        require(userSupplied[msg.sender] >= amount, "Insufficient supplied balance");
        
        // Accrue interest first
        _accrueInterest();
        
        // Calculate the interest earned on the withdrawn amount
        uint256 interestToWithdraw = (amount * userInterest[msg.sender]) / userSupplied[msg.sender];
        
        // Update user's supplied amount
        userSupplied[msg.sender] -= amount;
        totalSupplied -= amount;
        
        // Update user's accrued interest
        userInterest[msg.sender] -= interestToWithdraw;
        
        // Transfer principal + interest to the user
        uint256 totalToTransfer = amount + interestToWithdraw;
        require(token.transfer(msg.sender, totalToTransfer), "Token transfer failed");
        
        emit Withdraw(msg.sender, amount, interestToWithdraw);
    }
    
    /**
     * @dev Calculates and updates the accrued interest for the caller
     */
    function accrueInterest() external {
        _accrueInterest();
    }
    
    /**
     * @dev View function to get the current accrued interest for a user
     * @param user The address of the user
     * @return The current accrued interest (without updating state)
     */
    function getAccruedInterest(address user) external view returns (uint256) {
        if (userSupplied[user] == 0) {
            return userInterest[user];
        }
        
        uint256 timeElapsed = block.timestamp - lastAccrualTimestamp;
        uint256 interestAmount = (userSupplied[user] * annualInterestRate * timeElapsed) / (365 days * 10000);
        
        return userInterest[user] + interestAmount;
    }
    
    /**
     * @dev View function to get the total balance (principal + interest) for a user
     * @param user The address of the user
     * @return The total balance
     */
    function getTotalBalance(address user) external view returns (uint256) {
        uint256 interest = this.getAccruedInterest(user);
        return userSupplied[user] + interest;
    }
    
    /**
     * @dev Updates the annual interest rate (only owner)
     * @param _annualInterestRate The new annual interest rate in basis points
     */
    function updateInterestRate(uint256 _annualInterestRate) external onlyOwner {
        require(_annualInterestRate <= 10000, "Interest rate cannot exceed 100%");
        
        // Accrue interest first with the old rate
        _accrueInterest();
        
        // Update the interest rate
        annualInterestRate = _annualInterestRate;
        
        emit InterestRateUpdated(_annualInterestRate);
    }
    
    /**
     * @dev Internal function to accrue interest for the caller
     */
    function _accrueInterest() internal {
        if (block.timestamp <= lastAccrualTimestamp) {
            return;
        }
        
        if (userSupplied[msg.sender] > 0) {
            uint256 timeElapsed = block.timestamp - lastAccrualTimestamp;
            uint256 interestAmount = (userSupplied[msg.sender] * annualInterestRate * timeElapsed) / (365 days * 10000);
            
            userInterest[msg.sender] += interestAmount;
            
            emit InterestAccrued(msg.sender, interestAmount);
        }
        
        lastAccrualTimestamp = block.timestamp;
    }
} 