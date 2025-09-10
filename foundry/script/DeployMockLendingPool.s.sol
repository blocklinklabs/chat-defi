// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {MockLendingPool} from "../src/MockLendingPool.sol";
import {MockToken} from "../src/MockToken.sol";

contract DeployMockLendingPool is Script {
    function run() external returns (MockLendingPool) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address tokenAddress =0xdE1f15231e9BFfcF6fcC9593BbA852B0489B439C;
        uint256 annualInterestRate = 500; // 5% annual interest rate in basis points

        vm.startBroadcast(deployerPrivateKey);

        // Deploy lending pool contract
        MockLendingPool lendingPool = new MockLendingPool(tokenAddress, annualInterestRate);

        vm.stopBroadcast();

        console.log("MockLendingPool deployed at:", address(lendingPool));
        console.log("Token Address:", tokenAddress);
        console.log("Annual Interest Rate:", annualInterestRate);
        console.log("basis points", annualInterestRate / 100);
        console.log("Deployer address:", deployer);

        return lendingPool;
    }
} 