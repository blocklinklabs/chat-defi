// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title KaiaConfig
 * @dev Kaia-specific chain IDs and well-known addresses used by scripts/contracts
 * Note: Update addresses as Kaia publishes canonical USDT addresses.
 */
library KaiaConfig {
    // Chain IDs
    uint256 internal constant KAIA_MAINNET = 8217; // Kaia (formerly Klaytn) mainnet
    uint256 internal constant KAIA_TESTNET = 1001; // Kaia testnet

    // Placeholder USDT addresses on Kaia. Replace with canonical addresses when available.
    // These can be overridden by env vars in deployment scripts if needed.
    address internal constant KAIA_MAINNET_USDT = 0x0000000000000000000000000000000000000001;
    address internal constant KAIA_TESTNET_USDT = 0x0000000000000000000000000000000000000002;

    function isKaiaChain() internal view returns (bool) {
        return block.chainid == KAIA_MAINNET || block.chainid == KAIA_TESTNET;
    }

    function getUsdtAddress() internal view returns (address) {
        if (block.chainid == KAIA_MAINNET) {
            return KAIA_MAINNET_USDT;
        }
        if (block.chainid == KAIA_TESTNET) {
            return KAIA_TESTNET_USDT;
        }
        return address(0);
    }
}


