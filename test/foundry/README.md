# Foundry Solidity Tests

This directory contains comprehensive Solidity tests for the Crop Insurance with Chainlink Price Feeds project, written using the Foundry testing framework.

## Overview

The Foundry tests provide superior performance, better debugging capabilities, and more detailed gas reporting compared to JavaScript tests. All tests are written in Solidity using the `forge-std` testing library.

## Test Structure

```
test/foundry/
├── utils/
│   └── TestHelper.sol          # Base test utilities and helpers
├── mocks/
│   └── MockERC20.sol          # Mock contracts for testing
├── PremiumCollection.t.sol     # Premium collection mechanism tests
├── AutomatedWeatherMonitoring.t.sol  # Chainlink Automation tests
├── GasOptimization.t.sol       # Gas optimization and benchmarking
└── README.md                   # This file
```

## Prerequisites

1. **Install Foundry**:
   ```bash
   curl -L https://foundry.paradigm.xyz | bash
   foundryup
   ```

2. **Install Dependencies**:
   ```bash
   forge install foundry-rs/forge-std
   forge install OpenZeppelin/openzeppelin-contracts
   forge install smartcontractkit/chainlink
   ```

## Test Categories

### 1. Premium Collection Tests (`PremiumCollection.t.sol`)

Tests the escrow-based premium collection system:

- **Contract Creation**: ETH and ERC20 contract creation
- **Premium Payment**: Multi-token premium payments with validation
- **Refund Mechanisms**: Premium refunds for inactive contracts
- **Insurer Claims**: Premium claiming after contract completion
- **Integration Tests**: Complete lifecycle scenarios
- **Gas Optimization**: Gas usage analysis for premium operations

### 2. Automated Weather Monitoring Tests (`AutomatedWeatherMonitoring.t.sol`)

Tests Chainlink Automation integration:

- **Automation Interface**: `checkUpkeep()` and `performUpkeep()` compliance
- **Batch Processing**: Gas-efficient processing of multiple contracts
- **Individual Weather Checks**: Contract-level weather monitoring
- **Error Handling**: Fault tolerance and edge cases
- **Manual Overrides**: Emergency controls and manual operations
- **Integration Scenarios**: Complete automation lifecycles

### 3. Gas Optimization Tests (`GasOptimization.t.sol`)

Comprehensive gas analysis and optimization:

- **Contract Operations**: Creation, activation, deactivation gas costs
- **Premium Payments**: ETH vs ERC20 payment efficiency
- **Automation Costs**: Upkeep gas costs and batch efficiency
- **Token Calculations**: Price feed and conversion gas usage
- **Benchmarking**: Performance targets and comparisons

## Running Tests

### Basic Commands

```bash
# Build contracts
npm run forge:build

# Run all tests
npm run forge:test

# Run specific test categories
npm run forge:test:premium      # Premium collection tests
npm run forge:test:automation   # Automation tests
npm run forge:test:gas         # Gas optimization tests

# Generate gas reports
npm run forge:test:gas-report

# Generate coverage reports
npm run forge:test:coverage

# Format code
npm run forge:fmt

# Clean build artifacts
npm run forge:clean
```

### Advanced Testing

```bash
# Run tests with detailed output
forge test -vvv

# Run specific test contract
forge test --match-contract PremiumCollectionTest

# Run specific test function
forge test --match-test test_PayPremiumInETH

# Run tests with gas reporting
forge test --gas-report

# Generate coverage report
forge coverage --report lcov

# Create gas snapshots
forge snapshot
```

### Debugging Tests

```bash
# Run with maximum verbosity
forge test -vvvv

# Run specific failing test
forge test --match-test test_specific_function -vvvv

# Use debugger
forge test --debug test_function_name
```

## Test Structure and Conventions

### Base Test Class

All tests inherit from `TestHelper` which provides:

- **Common Setup**: Standard account setup with ETH balances
- **Utility Functions**: Time manipulation, address formatting, logging
- **Test Constants**: Standard durations, amounts, and addresses
- **Helper Methods**: Contract creation, premium calculations
- **Mock Management**: Price feed mocking, oracle simulation

### Test Naming Convention

```solidity
function test_[Category]_[Scenario]() public {
    // Test implementation
}

function test_Revert[Scenario]() public {
    // Revert test implementation
}

function test_Gas_[Operation]() public {
    // Gas measurement test
}
```

### Example Test Structure

```solidity
contract PremiumCollectionTest is TestHelper {
    AutomatedInsuranceProvider public provider;
    MockERC20 public usdc;
    
    function setUp() public {
        setupAccounts();
        // Deploy contracts and setup state
    }
    
    function test_PayPremiumInETH() public {
        // Create contract
        // Pay premium
        // Verify state changes
        // Check events
    }
    
    function test_RevertPaymentFromNonClient() public {
        // Setup scenario
        // Expect revert
        // Attempt invalid operation
    }
}
```

## Mock Contracts

### MockERC20
- Standard ERC20 implementation with mint/burn functions
- Configurable decimals for testing different token types
- Used for USDC (6 decimals), DAI (18 decimals), etc.

### MockAggregatorV3
- Chainlink price feed simulator
- Configurable price and staleness
- Used for ETH/USD, USDC/USD, DAI/USD feeds

### MockLinkToken
- LINK token simulator for oracle payments
- Always returns true for transfers (testing convenience)

### MockOracle
- Chainlink oracle simulator
- Request/response cycle simulation
- Callback function testing

## Gas Optimization Targets

The gas optimization tests enforce the following benchmarks:

| Operation | Target Gas | Max Gas |
|-----------|------------|---------|
| Contract Creation | < 2.5M | 3M |
| Premium Payment | < 150k | 200k |
| Single Upkeep | < 400k | 500k |
| Batch Upkeep (10) | < 1.5M | 2M |
| Weather Check | < 250k | 300k |
| Token Calculation | < 30k | 50k |

## Configuration

### Foundry Configuration (`foundry.toml`)

Key settings:
- Solidity version: 0.8.17
- Optimizer: enabled with 200 runs
- Test verbosity: 2
- Fuzz runs: 1000
- Gas reports: enabled for all contracts

### Environment Variables

Tests use the following environment variables:
- `MAINNET_RPC_URL`: For forking tests (optional)
- `SEPOLIA_RPC_URL`: For testnet integration (optional)
- `ETHERSCAN_API_KEY`: For contract verification (optional)

## Best Practices

### Test Organization

1. **Setup**: Use `setUp()` for common test initialization
2. **Isolation**: Each test should be independent
3. **Clarity**: Use descriptive test names and clear assertions
4. **Coverage**: Test both success and failure scenarios
5. **Gas Awareness**: Include gas measurements for critical operations

### Assertion Patterns

```solidity
// State assertions
assertTrue(condition);
assertFalse(condition);
assertEq(actual, expected);
assertGt(actual, minimum);
assertLt(actual, maximum);

// Event assertions
vm.expectEmit(true, true, true, true);
emit EventName(param1, param2);
contractCall();

// Revert assertions
vm.expectRevert("Error message");
contractCall();
```

### Common Patterns

```solidity
// Time manipulation
skipTime(DAY_IN_SECONDS);
skipToNextDay();

// Account switching
vm.startPrank(user);
// operations as user
vm.stopPrank();

// Balance tracking
uint256 balanceBefore = user.balance;
// operation
uint256 balanceAfter = user.balance;
assertEq(balanceAfter - balanceBefore, expectedChange);

// Gas measurement
uint256 gasStart = gasleft();
// operation
uint256 gasUsed = gasStart - gasleft();
console.log("Gas used:", gasUsed);
```

## Troubleshooting

### Common Issues

1. **Import Errors**: Ensure Foundry dependencies are installed
2. **Gas Limit Exceeded**: Check for infinite loops or excessive operations
3. **Time Issues**: Use `vm.warp()` for time-based tests
4. **Mock Issues**: Verify mock contracts are properly configured

### Debug Tips

1. Use `console.log()` for debugging output
2. Use `-vvvv` for maximum test verbosity
3. Use `forge test --debug` for step-by-step debugging
4. Check `foundry.toml` configuration for issues

## Contributing

When adding new tests:

1. Follow the existing naming conventions
2. Add appropriate gas measurements for new operations
3. Include both positive and negative test cases
4. Update this README if adding new test categories
5. Ensure tests are deterministic and isolated

## Performance Benefits

Foundry tests provide significant performance improvements:

- **Speed**: 10-100x faster than JavaScript tests
- **Gas Reporting**: Built-in detailed gas analysis
- **Debugging**: Better stack traces and debugging tools
- **Coverage**: More accurate coverage reporting
- **Fuzzing**: Built-in property-based testing capabilities

For development and CI/CD, Foundry tests are the recommended approach for comprehensive smart contract testing.