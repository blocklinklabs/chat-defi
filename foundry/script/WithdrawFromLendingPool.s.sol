// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {MockLendingPool} from "../src/MockLendingPool.sol";
import {MockToken} from "../src/MockToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract WithdrawFromLendingPool is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address lendingPoolAddress = vm.envAddress("LENDING_POOL_ADDRESS");
        address tokenAddress = vm.envAddress("TOKEN_ADDRESS");
        uint256 withdrawAmount = vm.envUint("WITHDRAW_AMOUNT"); // Amount in base units

        MockLendingPool lendingPool = MockLendingPool(lendingPoolAddress);
        IERC20 token = IERC20(tokenAddress);

        // Log initial state
        console.log("Withdrawal demonstration");
        console.log("===================");
        console.log("Deployer:", deployer);
        console.log("Lending Pool:", lendingPoolAddress);
        console.log("Token:", tokenAddress);
        console.log("Initial deployer token balance:", token.balanceOf(deployer));
        console.log("Initial deployer supplied in pool:", lendingPool.userSupplied(deployer));
        console.log("Initial accrued interest:", lendingPool.getAccruedInterest(deployer));
        console.log("Initial total balance in pool:", lendingPool.getTotalBalance(deployer));
        
        vm.startBroadcast(deployerPrivateKey);

        // First accrue interest to update the state
        lendingPool.accrueInterest();
        
        // Withdraw from the lending pool
        lendingPool.withdraw(withdrawAmount);
        
        vm.stopBroadcast();

        // Log final state
        console.log("Withdrawal completed");
        console.log("===================");
        console.log("Withdraw amount:", withdrawAmount);
        console.log("Final deployer token balance:", token.balanceOf(deployer));
        console.log("Final deployer supplied in pool:", lendingPool.userSupplied(deployer));
        console.log("Final accrued interest:", lendingPool.getAccruedInterest(deployer));
        console.log("Final total balance in pool:", lendingPool.getTotalBalance(deployer));
    }
} 