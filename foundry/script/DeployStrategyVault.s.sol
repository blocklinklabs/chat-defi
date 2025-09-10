// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {StrategyVault} from "../src/StrategyVault.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {KaiaConfig} from "../src/KaiaConfig.sol";
import {DomaConfig} from "../src/DomaConfig.sol";

contract DeployStrategyVault is Script {
    function run() external returns (StrategyVault) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        // Prefer an explicit ASSET_TOKEN from env; otherwise, auto-resolve Kaia USDT when on Kaia
        address assetToken;
        try vm.envAddress("ASSET_TOKEN") returns (address envToken) {
            assetToken = envToken;
        } catch {
            address kaiaUSDT = KaiaConfig.getUsdtAddress();
            if (kaiaUSDT != address(0)) {
                assetToken = kaiaUSDT;
            } else {
                revert("ASSET_TOKEN not set and non-Kaia chain detected");
            }
        }
        string memory name = "Vault Token";
        string memory symbol = "vTKN";

        vm.startBroadcast(deployerPrivateKey);

        // Deploy vault contract
        StrategyVault vault = new StrategyVault(IERC20(assetToken), name, symbol);

        // Configure vault if needed
        // (Use additional environment variables to configure fees, etc. if desired)
        // Optionally configure Doma Protocol endpoint for DomainFi hooks
        // DOMA_PROTOCOL preference order:
        // 1) explicit DOMA_PROTOCOL env
        // 2) DOMA_NETWORK env hint ("DOMA_TESTNET"|"SEPOLIA"|"BASE_SEPOLIA"), choose a canonical contract (proxy record or gateway)
        // 3) none
        bool configuredDoma = false;
        try vm.envAddress("DOMA_PROTOCOL") returns (address doma) {
            if (doma != address(0)) {
                vault.setDomaProtocol(doma);
                console.log("Configured Doma Protocol (env DOMA_PROTOCOL):", doma);
                configuredDoma = true;
            }
        } catch {}

        if (!configuredDoma) {
            try vm.envString("DOMA_NETWORK") returns (string memory net) {
                bytes32 h = keccak256(bytes(net));
                address endpoint = address(0);
                if (h == keccak256("DOMA_TESTNET")) {
                    endpoint = DomaConfig.domaTestnet().proxyDomaRecord;
                } else if (h == keccak256("SEPOLIA")) {
                    endpoint = DomaConfig.sepolia().proxyDomaRecord;
                } else if (h == keccak256("BASE_SEPOLIA")) {
                    endpoint = DomaConfig.baseSepolia().proxyDomaRecord;
                }
                if (endpoint != address(0)) {
                    vault.setDomaProtocol(endpoint);
                    console.log("Configured Doma Protocol (DOMA_NETWORK=", net, "):", endpoint);
                }
            } catch {}
        }

        vm.stopBroadcast();

        console.log("StrategyVault deployed at:", address(vault));
        console.log("Vault Name:", name);
        console.log("Vault Symbol:", symbol);
        console.log("Asset Token:", assetToken);

        // Kaia-specific note for logs
        if (KaiaConfig.isKaiaChain()) {
            console.log("Kaia chain detected (chainid=%s). Using Kaia-native USDT.", block.chainid);
        }

        return vault;
    }
}
