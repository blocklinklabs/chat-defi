// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {MockLendingPool} from "../src/MockLendingPool.sol";
import {MockToken} from "../src/MockToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DepositToLendingPool is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address lendingPoolAddress =0x814b2fa4018cd54b1BbD8662a8B53FeB4eD24D7D;
        address tokenAddress =0xdE1f15231e9BFfcF6fcC9593BbA852B0489B439C;
        uint256 depositAmount = 100; // Amount in base units

        MockLendingPool lendingPool = MockLendingPool(lendingPoolAddress);
        IERC20 token = IERC20(tokenAddress);

        // Log initial state
        console.log("Deposit demonstration");
        console.log("===================");
        console.log("Deployer:", deployer);
        console.log("Lending Pool:", lendingPoolAddress);
        console.log("Token:", tokenAddress);
        console.log("Initial deployer token balance:", token.balanceOf(deployer));
        console.log("Initial lending pool token balance:", token.balanceOf(lendingPoolAddress));
        
        vm.startBroadcast(deployerPrivateKey);

        // Approve tokens for lending pool if needed
        uint256 currentAllowance = token.allowance(deployer, lendingPoolAddress);
        if (currentAllowance < depositAmount) {
            token.approve(lendingPoolAddress, type(uint256).max);
            console.log("Approved tokens for lending pool");
        }

        // Deposit to lending pool
        lendingPool.deposit(depositAmount);
        
        vm.stopBroadcast();

        // Log final state
        console.log("Deposit completed");
        console.log("===================");
        console.log("Deposit amount:", depositAmount);
        console.log("Final deployer token balance:", token.balanceOf(deployer));
        console.log("Final lending pool token balance:", token.balanceOf(lendingPoolAddress));
        console.log("Deployer supplied amount in pool:", lendingPool.userSupplied(deployer));
    }
} 