# Alphix Core Repository

![Alphix Logo](./branding-materials/logos/type/LogoTypeWhite.png)

> **A Uniswap V4 Dynamic-Fee Hook with JIT Liquidity Rehypothecation**


## Overview


### Our Vision

Alphix is building the foundation for the next generation of Automated Market Makers (AMMs) and Concentrated Liquidity AMMs (CLMMs) through composable and customizable markets.

Think dynamic fees, liquidity rehypothecation, automated rebalancing, and other market efficiency innovations — all coexisting in a single pool.

### Our Hook

This repository presents Alphix's flagship product: a **Dynamic Fee Hook with JIT Liquidity Rehypothecation**.

We have implemented a **Uniswap V4 Hook** that:
- **Adjusts LP fees dynamically** based on pool ratio signals using EMA smoothing
- **Provides Just-In-Time (JIT) liquidity** for capital-efficient swaps
- **Integrates with ERC-4626 yield vaults** to earn additional yield on deposited assets

Fee updates are computed from deviations between current and target volume/TVL ratios. For security, we apply global bounds, cooldowns, and side-specific throttling to control sensitivity.

## Architecture

The system follows a modular architecture with clear separation of concerns:

### Core Components

1. **Hook Contract** ([`Alphix.sol`](src/Alphix.sol))
   - Implements Uniswap V4 `IHooks` interface
   - Manages dynamic fee computation and updates
   - Provides JIT liquidity via `beforeSwap`/`afterSwap` hooks
   - ERC-20 token representing user shares in the rehypothecation system
   - Integrates with ERC-4626 yield sources for yield farming

2. **ETH Variant** ([`AlphixETH.sol`](src/AlphixETH.sol))
   - Extension of Alphix for pools with native ETH
   - Automatic WETH wrapping/unwrapping
   - Handles native currency deposits and withdrawals

3. **Dynamic Fee Library** ([`DynamicFee.sol`](src/libraries/DynamicFee.sol))
   - Pure functions for fee calculations
   - EMA computation with configurable lookback periods
   - Fee clamping and out-of-bounds (OOB) detection
   - Streak tracking for consecutive OOB hits

4. **ReHypothecation Library** ([`ReHypothecation.sol`](src/libraries/ReHypothecation.sol))
   - ERC-4626 yield vault integration
   - Deposit/withdrawal helpers
   - Share-to-asset conversion utilities
   - Yield source migration support

### Supporting Infrastructure

- **Global Constants** ([`AlphixGlobalConstants.sol`](src/libraries/AlphixGlobalConstants.sol)): System-wide bounds and configuration limits
- **Interfaces** ([`src/interfaces/`](src/interfaces/)): External API definitions for all contracts
- **Base Contract** ([`BaseDynamicFee.sol`](src/BaseDynamicFee.sol)): OpenZeppelin-based foundation for dynamic fee hooks

## Pool Parameters

Each pool is configured with parameters that control fee sensitivity:

| Parameter | Description |
|-----------|-------------|
| `minFee` / `maxFee` | Fee bounds (uint24) |
| `baseMaxFeeDelta` | Max adjustment per OOB hit (uint24) |
| `lookbackPeriod` | EMA smoothing period in days (uint24) |
| `minPeriod` | Cooldown between updates in seconds (uint256) |
| `ratioTolerance` | Band width around target ratio (1e18 scaled) |
| `linearSlope` | Sensitivity to deviation (1e18 scaled) |
| `maxCurrentRatio` | Upper bound for ratios |
| `lowerSideFactor` / `upperSideFactor` | Side-specific throttling multipliers |

All parameters are bounded by global constants for additional security.

## Security

### Security Patterns

- **OpenZeppelin 5 Contracts**: Ownable2Step, ReentrancyGuardTransient, Pausable
- **Access Control**:
  - Hook owner with two-step ownership transfers
  - AccessManager for role-based permissions (FEE_POKER, YIELD_MANAGER)
- **State Protection**:
  - ReentrancyGuard on sensitive operations
  - Pausable for emergency stops
  - Cooldowns to prevent manipulation

### Economic Security

- **Global Bounds**: System-wide limits on fees, ratios, and parameters
- **Cooldown Enforcement**: Time-based rate limiting on fee updates
- **Side-Specific Throttling**: Asymmetric adjustments via upper/lower side factors
- **Streak Multipliers**: Progressive fee adjustments for sustained out-of-bounds conditions

## Testing

The protocol includes comprehensive testing across multiple layers:

- **Unit Tests**: Isolated component validation (libraries, math functions)
- **Integration Tests**: Cross-component interaction verification
- **Full Cycle Tests**: End-to-end lifecycle scenarios including 30-day simulations
- **Invariant Tests**: Property-based stateful fuzzing to ensure critical invariants hold
- **Fuzz Testing**: Randomized input testing with 256+ runs per test

All tests are built with Foundry.

## Development

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Git with submodules support

### Setup

```bash
# Clone repository with submodules
git clone --recurse-submodules https://github.com/alphixfi/alphix-public.git
cd alphix-public

# Install dependencies
forge install

# Build contracts
forge build
```

### Running Tests

```bash
# Run all tests
forge test

# Run with gas reporting
forge test --gas-report

# Run specific test suite
forge test --match-path "test/alphix/integration/**/*.sol"

# Run with verbosity
forge test -vvv
```

### Deployment

Located in `script/alphix/`.

#### Running Scripts

```bash
# 1. Set up environment
cp .env.example .env
# Edit .env with your configuration
source .env

# 2. Deploy core system
forge script script/alphix/00_DeployAccessManager.s.sol --rpc-url $RPC_URL --broadcast --verify
forge script script/alphix/01_DeployAlphix.s.sol --rpc-url $RPC_URL --broadcast --verify
# Or for ETH pools:
# forge script script/alphix/01_DeployAlphixETH.s.sol --rpc-url $RPC_URL --broadcast --verify

# 3. Configure roles
forge script script/alphix/02_ConfigureRoles.s.sol --rpc-url $RPC_URL --broadcast
forge script script/alphix/02b_SetFeePoker.s.sol --rpc-url $RPC_URL --broadcast
forge script script/alphix/02c_SetYieldManager.s.sol --rpc-url $RPC_URL --broadcast

# 4. Create pool and configure rehypothecation
forge script script/alphix/03_CreatePool.s.sol --rpc-url $RPC_URL --broadcast
forge script script/alphix/04_ConfigureReHypothecation.s.sol --rpc-url $RPC_URL --broadcast

# 5. Add liquidity
forge script script/alphix/05_AddLiquidity.s.sol --rpc-url $RPC_URL --broadcast
# Or for rehypothecated liquidity:
# forge script script/alphix/05b_AddRHLiquidity.s.sol --rpc-url $RPC_URL --broadcast

# 6. Test swaps and dynamic fees
forge script script/alphix/06_Swap.s.sol --rpc-url $RPC_URL --broadcast
forge script script/alphix/07_PokeFee.s.sol --rpc-url $RPC_URL --broadcast

# 7. (Optional) Transfer ownership to multisig
forge script script/alphix/08_TransferOwnership.s.sol --rpc-url $RPC_URL --broadcast
forge script script/alphix/08b_AcceptOwnership.s.sol --rpc-url $RPC_URL --broadcast
```

### Testnet Deployment

Coming soon!

## Links & Resources

- [Website](https://www.alphix.fi/)
- [Documentation](https://alphix.gitbook.io/docs)
- [Branding Material](./branding-materials/)

## Partners

- Base: Base Batch 001 & IncuBase
- Uniswap Foundation: Buildathon Season
- More partners to come!

## Acknowledgements

Alphix builds on top of Uniswap V4, leveraging its hook system. Our implementation follows the official **[Uniswap v4 template](https://github.com/uniswapfoundation/v4-template)** and closely follows **[OpenZeppelin's Uniswap Hook template](https://github.com/OpenZeppelin/uniswap-hooks)**. This helps us ensure compatibility and best practices.

## License

This project is licensed under the **Business Source License 1.1 (BUSL-1.1)**.

- **Licensor:** Alphix Association
- **Change Date:** December 25, 2028
- **Change License:** MIT

After the Change Date, the code will be available under the MIT License. See [LICENSE](./LICENSE) for full terms.