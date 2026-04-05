# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Decentralized parametric crop insurance platform on Ethereum. Pays out automatically when drought conditions (3+ consecutive days with zero rainfall) are detected via Chainlink oracles. Supports multi-token premiums (ETH, USDC, DAI, USDT) with Chainlink Price Feeds for conversion, Chainlink Automation for daily weather monitoring, and Ethereum Attestation Service (EAS) for immutable insurance records.

## Build & Test Commands

```bash
# Install dependencies
npm install

# Compile contracts (Truffle)
npm run compile

# Run all Truffle (JS) tests
npm test

# Run specific Truffle test suites
npm run test:premium          # PremiumCollection_test.js
npm run test:automation       # AutomatedWeatherMonitoring_test.js
npm run test:multitoken       # MultiToken_test.js

# Run all Foundry (Solidity) tests
npm run forge:test

# Run specific Foundry test contracts
npm run forge:test:premium    # PremiumCollection.t.sol
npm run forge:test:automation # AutomatedWeatherMonitoring.t.sol
npm run forge:test:gas        # GasOptimization.t.sol

# Foundry utilities
npm run forge:test:gas-report # Gas usage report
npm run forge:test:coverage   # Code coverage
npm run forge:fmt             # Format Solidity (Foundry)

# Lint Solidity
npm run solhint
```

## Architecture

The system has three contract layers, each building on the previous:

1. **`Crop-Insurance.sol`** — Base layer. `InsuranceProvider` (factory) creates `InsuranceContract` instances. Each `InsuranceContract` uses ChainlinkClient to request rainfall data from two weather APIs (WorldWeatherOnline, Weatherbit), averages the results, and tracks consecutive days without rain. Uses `DAY_IN_SECONDS = 60` for testing.

2. **`Crop-Insurance-Premium.sol`** — Extends the base with an escrow-based premium collection system. Adds `PremiumInfo` tracking, 24-hour grace periods, multi-token support via Chainlink Price Feeds, automatic refunds for inactive contracts, and insurer claim functions. Also uses `DAY_IN_SECONDS = 60`.

3. **`AutomatedInsurance.sol`** — Production-ready version. Integrates Chainlink Automation (`AutomationCompatibleInterface` with `checkUpkeep`/`performUpkeep`), EAS attestations via `EASInsuranceManager`, gas-optimized struct packing (`PremiumInfo` uses `uint128`/`uint64`), batch processing (max 10 contracts per upkeep), and uses `DAY_IN_SECONDS = 86400`.

**EAS subsystem** (`contracts/eas/`): `InsuranceSchemas` defines 5 attestation schemas (policy, weather, claim, compliance, premium). `EASInsuranceManager` creates/verifies/revokes attestations with role-based access (authorizedAttestors, oracleNodes, complianceProviders). `IEASInsurance` is the interface.

## Key Design Details

- Solidity `^0.8.17` — uses built-in overflow protection, no SafeMath
- Reentrancy protection: OpenZeppelin `ReentrancyGuard` + Checks-Effects-Interactions pattern
- Chainlink Price Feed for ETH/USD hardcoded to `0x9326BFA02ADD2366b30bacB125260Af641031331` (Kovan) in base contracts; Sepolia addresses used in Foundry test helpers
- Oracle pattern: two oracle requests per weather check, results averaged — `currentRainfallList[2]` collects both, `dataRequestsSent` counter triggers averaging after second response
- Drought payout triggers at `DROUGHT_DAYS_THRESHOLD = 3` consecutive zero-rainfall days
- Contract end: if insurer didn't make enough data requests (`requestCount < duration/DAY_IN_SECONDS - 2`), client gets a premium refund

## Dual Test Frameworks

- **Truffle tests** (`test/*.js`): JavaScript tests run against Ganache. Use `@openzeppelin/test-helpers` and `@chainlink/test-helpers`.
- **Foundry tests** (`test/foundry/*.t.sol`): Solidity tests using forge-std. `TestHelper.sol` provides shared constants, mock helpers (`mockPriceFeed`, `mockOracleResponse`), and gas assertion utilities. Foundry config: 1000 fuzz runs default, 10000 in CI profile.

## Gas Optimization Targets

| Operation | Target | Max |
|-----------|--------|-----|
| Contract Creation | < 2.5M | 3M |
| Premium Payment | < 150k | 200k |
| Single Upkeep | < 400k | 500k |
| Batch Upkeep (10) | < 1.5M | 2M |

## Deployment

- Local: `npx ganache-cli` then `npm run migrate:dev`
- Sepolia: `npm run migrate:sepolia` (requires `MNEMONIC` and `SEPOLIA_RPC_URL` in `.env`)
- Mainnet: `npm run migrate:live` (requires `MNEMONIC` and `MAINNET_RPC_URL` in `.env`)
- Foundry remappings use git submodules in `lib/` (forge-std, openzeppelin-contracts)
