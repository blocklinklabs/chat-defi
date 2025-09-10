// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {MockToken} from "../src/MockToken.sol";

contract DeployMockToken is Script {
    function run() external returns (MockToken) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        string memory name = "Mock Token";
        string memory symbol = "MOCK";
        uint8 decimals = 18;
        uint256 initialSupply = 1000000; // 1 million tokens

        vm.startBroadcast(deployerPrivateKey);

        // Deploy token contract
        MockToken token = new MockToken(name, symbol, decimals, initialSupply);

        vm.stopBroadcast();

        console.log("MockToken deployed at:", address(token));
        console.log("Token Name:", name);
        console.log("Token Symbol:", symbol);
        console.log("Token Decimals:", decimals);
        console.log("Initial Supply:", initialSupply);
        
        // Log the deployer's token balance
        uint256 deployerBalance = token.balanceOf(deployer);
        console.log("Deployer address:", deployer);
        console.log("Deployer token balance:", deployerBalance / (10 ** decimals), symbol);

        return token;
    }
} 