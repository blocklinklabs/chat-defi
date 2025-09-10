// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MockToken
 * @dev A simple ERC20 token for testing the lending pool
 */
contract MockToken is ERC20, Ownable {
    uint8 private _decimals;

    /**
     * @dev Constructor to initialize the token with name, symbol, and decimals
     * @param name The name of the token
     * @param symbol The symbol of the token
     * @param tokenDecimals The number of decimals for the token
     * @param initialSupply The initial supply of tokens to mint to the creator
     */
    constructor(
        string memory name,
        string memory symbol,
        uint8 tokenDecimals,
        uint256 initialSupply
    ) ERC20(name, symbol) Ownable(msg.sender) {
        _decimals = tokenDecimals;
        _mint(msg.sender, initialSupply * (10 ** tokenDecimals));
    }

    /**
     * @dev Override decimals function to return custom decimals value
     */
    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    /**
     * @dev Function to mint new tokens (only owner)
     * @param to The address to mint tokens to
     * @param amount The amount of tokens to mint
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
} 