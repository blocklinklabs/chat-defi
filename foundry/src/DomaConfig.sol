// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title DomaConfig
 * @dev Reference addresses for Doma Protocol on popular testnets.
 * Source: Doma docs (testnet section). Update if docs change.
 */
library DomaConfig {
    // Chain IDs
    uint256 internal constant SEPOLIA = 11155111;
    uint256 internal constant BASE_SEPOLIA = 84532; // Base Sepolia
    // Other chains (IDs may vary or be non-EVM; left undefined here)

    struct DomaAddresses {
        address ownershipToken;
        address proxyDomaRecord;
        address crossChainGateway;
        address domaRecord; // present on Doma Testnet
        address forwarder;  // present on Doma Testnet
    }

    // Doma Testnet (custom; no canonical chainId exposed here)
    function domaTestnet() internal pure returns (DomaAddresses memory a) {
        a.domaRecord = 0xF6A92E0f8bEa4174297B0219d9d47fEe335f84f8;
        a.crossChainGateway = 0xCE1476C791ff195e462632bf9Eb22f3d3cA07388;
        a.forwarder = 0xf17beC16794e018E2F0453a1282c3DA3d121f410;
        a.ownershipToken = 0x424bDf2E8a6F52Bd2c1C81D9437b0DC0309DF90f;
        a.proxyDomaRecord = 0xb1508299A01c02aC3B70c7A8B0B07105aaB29E99;
    }

    function sepolia() internal pure returns (DomaAddresses memory a) {
        a.ownershipToken = 0x9A374915648f1352827fFbf0A7bB5752b6995eB7;
        a.proxyDomaRecord = 0xD9A0E86AACf2B01013728fcCa9F00093B9b4F3Ff;
        a.crossChainGateway = 0xEC67EfB227218CCc3c7032a6507339E7B4D623Ad;
    }

    function baseSepolia() internal pure returns (DomaAddresses memory a) {
        a.ownershipToken = 0x2f45DfC5f4c9473fa72aBdFbd223d0979B265046;
        a.proxyDomaRecord = 0xa40aA710F0C77DF3De6CEe7493d1FfF3715D59Da;
        a.crossChainGateway = 0xC721925DF8268B1d4a1673D481eB446B3EDaAAdE;
    }
}


