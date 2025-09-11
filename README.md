# Project Overview

![alt text](image.png)

The [chatDeFi.app](http://chatdefi.app) AI agent democratizes DeFi by enabling anyone to create, execute and manage DeFi investment strategies by simply typing in their desired DeFi investment strategy into a user-friendly chatbot interface. Our AI agent then executes these strategies automatically.

For example, you could instruct our AI agent to:

“Please allocate my wallet funds to the highest yielding DeFi lending pools that earn at least 5% APY. Also, to manage my risk, split my wallet funds across 2 lending pools with 70% of my funds in one pool and 30% in another. If my portfolio loses 10% of its funds, then stop managing my portfolio.”

Our AI agent will parse your natural language request into the corresponding DeFi strategy and actively manage and rebalance your portfolio according to the parameters you define.

Key Components

- Front-end:
  - [chatDeFi.app](http://chatdefi.app) houses the chatbot interface to enter in your desired DeFi strategy in plain english.
- Back-end:
  - Our AI agent will process/interpret your strategy, manage your strategy vault by depositing/withdrawing your vault funds to/from the approriate DeFi protocol according to your investment strategy parameters, and auto-stop if certain risk parameters are reached.

Key Features

- Blockchains supported:
  - Celo, Polygon, Rootstock, Saga, Kaia (Mini Dapp target)
- DeFi protocols supported:
  - DeFi lending (i.e. Aave, Compound, etc. (varies by blockchain))
- Strategies supported:
  - i) Portfolio allocation strategy (i.e. 80%/20% or 70/30% splits across x number of DeFi lending pools),
  - ii) Risk management strategy (i.e. auto-stop AI agent if portfolio value falls 10%)
  - iii) Min. Return requirements (i.e. only invest in pools with min. return of x%)

Future Roadmap

- Support additional DeFi protocols (DEX trading, perpetual trading, yield optimizers)
- "Invest" feature - co-invest alongside an existing DeFi strategy (aka vault) on the platform (instead of creating your own DeFi investment)

Architecture
![alt text](image-2.png)

## Kaia Mini Dapp SDK and Stablecoin Integration

- We added Kaia-specific configuration and USDT auto-resolution via `foundry/src/KaiaConfig.sol`.
- The `StrategyVault` now emits Mini Dapp-friendly events on Kaia chains:
  - `KaiaMiniDappAction(caller, action, timestamp, chainId)` on deposit, withdraw, redeem, execute.
- The deploy script auto-detects Kaia chain IDs and defaults to Kaia-native USDT when `ASSET_TOKEN` is not provided (`foundry/script/DeployStrategyVault.s.sol`).
- A LINE Mini Dapp can subscribe to these events to drive UI updates using the Kaia Mini Dapp SDK.

### Deploying on Kaia

1. `export PRIVATE_KEY=...`
2. Optional override: `export ASSET_TOKEN=0x...` (otherwise Kaia USDT from `KaiaConfig` is used on Kaia chains)
3. Run: `forge script foundry/script/DeployStrategyVault.s.sol:DeployStrategyVault --rpc-url $KAIA_RPC --broadcast -vvvv`
4. Verify `KaiaMiniDappAction` events on user actions.

## Doma Protocol Integration (DomainFi)

- Doma integration hooks have been added to `StrategyVault`:
  - Optional endpoint via `setDomaProtocol(address)`; store in `domaProtocol`.
  - Emits `DomaAction(caller, action, timestamp, domaProtocol)` on deposit/withdraw/redeem/execute when configured.
- Minimal placeholder interface `foundry/src/IDomaProtocol.sol` allows wiring concrete Doma contracts later.
- Deployment script supports optional env `DOMA_PROTOCOL` to configure the endpoint automatically.
- Auto-configuration via `DOMA_NETWORK` is also supported: `DOMA_TESTNET` | `SEPOLIA` | `BASE_SEPOLIA`. The script selects Doma’s `proxyDomaRecord` for the chosen network as the endpoint.

### Why Doma

- Domains as tokenized RWAs enable new DeFi primitives (collateral, auctions, portfolio signals) that align with our AI-driven strategy vaults.
- Doma’s cross-chain and marketplace infra provides orderflow, events, and valuation surfaces our agent can react to.
- Hackathon alignment: We can demonstrate on-chain activity and DomainFi impact without overhauling our core architecture.

### How we integrated Doma

- Smart contracts:
  - Added `domaProtocol` address + `setDomaProtocol(address)` in `StrategyVault`.
  - Emitted `DomaAction` on user flows (deposit/withdraw/redeem/execute) for bots/analytics.
  - Created `IDomaProtocol.sol` as an integration touchpoint.
- Tooling & config:
  - Added `DomaConfig.sol` with documented testnet addresses (Doma Testnet, Sepolia, Base Sepolia).
  - Updated deploy script to prefer `DOMA_PROTOCOL` or infer via `DOMA_NETWORK` (e.g., `SEPOLIA`).
- Ops & demo:
  - Teams can point `DOMA_PROTOCOL` to Doma’s `proxyDomaRecord` or `crossChainGateway` for event-driven workflows and dashboards.

### How to test Doma hooks

1. `export DOMA_PROTOCOL=0xYourDomaTestnetEndpoint`
2. Deploy the vault using the standard script.
3. Perform deposits/withdrawals and observe `DomaAction` events for DomainFi analytics and bot subscriptions.

## Mini Dapp SDK Integration (LINE / Kaia)

### Why Mini Dapp

- Native wallet/payment flows in LINE reduce friction and boost conversion for retail users.
- SDK-driven events align with our on-chain `KaiaMiniDappAction` and `MiniDappPaymentIntent`, enabling coherent UX + audit trail.
- Hackathon requirements (test mode, domain whitelisting) enforced via code and environment variables for reproducibility.

### How we integrated the SDK

- Frontend singleton at `frontend/miniapp/sdk.ts` initializes the SDK once:
  - `NEXT_PUBLIC_MINI_DAPP_CLIENT_ID` and `NEXT_PUBLIC_MINI_DAPP_CHAIN_ID` (default `1001` testnet; set `8217` for mainnet)
  - Exposes `getWalletProvider`, `getPaymentProvider`, and `createTestPayment()` which enforces `testMode: true`.
- Vault function `recordMiniDappPaymentIntent(bytes32 intentId, bool testMode)` emits `MiniDappPaymentIntent` for audit/logging.
- Recommended to generate `intentId = keccak256(clientSession || paymentId)` and call `recordMiniDappPaymentIntent` pre/post payment.

### SDK Requirements we adhered to

- Domain whitelisting: run on `http://localhost:3000` locally and pre-register any other domains.
- Bitget Wallet (Reown) integration: complete domain verification and share `projectId` with Tech Support.
- Test Mode: all payment creation uses `testMode: true`. If set to `false`, revenue attribution shifts to Kaia Wave.

### Usage (frontend)

1. Install SDK in your frontend project: `npm i @linenext/dapp-portal-sdk`
2. Set env:
   - `NEXT_PUBLIC_MINI_DAPP_CLIENT_ID=...`
   - `NEXT_PUBLIC_MINI_DAPP_CHAIN_ID=1001`
3. Example:
   - Initialize once and call `createTestPayment({ amount: '1', asset: 'USDT' })`.
   - Optionally call the vault `recordMiniDappPaymentIntent(intentId, true)` before/after for audit.

# Celo Prize Requirement Details

See [Readme (Celo deployment).md](<./Readme%20(Celo%20deployment).md>)

# Polygon Prize Requirement Details

See [Readme (Polygon deployment).md](<Readme%20(Polygon%20deployment).md>)

# Rootstock Prize Requirement Details

See [Readme (Rootstock deployment).md](<./Readme%20(Rootstock%20deployment).md>)

# Saga Prize Requirement Details

See [Readme (Saga deployment).md](<./Readme%20(Saga%20deployment).md>)
