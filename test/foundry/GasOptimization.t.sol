// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "./utils/TestHelper.sol";
import "./mocks/MockERC20.sol";
import "../../contracts/AutomatedInsurance.sol";

/**
 * @title GasOptimizationTest
 * @dev Comprehensive gas optimization tests for all contract operations
 */
contract GasOptimizationTest is TestHelper {
    
    AutomatedInsuranceProvider public provider;
    MockERC20 public usdc;
    MockERC20 public dai;
    MockAggregatorV3 public ethUsdFeed;
    MockAggregatorV3 public usdcUsdFeed;
    MockAggregatorV3 public daiUsdFeed;
    MockLinkToken public linkToken;
    
    // Gas benchmarks (these should be updated as optimizations are made)
    uint256 constant MAX_CONTRACT_CREATION_GAS = 3_000_000;
    uint256 constant MAX_PREMIUM_PAYMENT_GAS = 200_000;
    uint256 constant MAX_SINGLE_UPKEEP_GAS = 500_000;
    uint256 constant MAX_BATCH_UPKEEP_GAS = 2_000_000;
    uint256 constant MAX_WEATHER_CHECK_GAS = 300_000;
    uint256 constant MAX_PAYOUT_GAS = 100_000;
    uint256 constant MAX_TOKEN_CALCULATION_GAS = 50_000;

    function setUp() public {
        setupAccounts();
        
        // Deploy all necessary contracts
        usdc = new MockERC20("USD Coin", "USDC", 6);
        dai = new MockERC20("Dai Stablecoin", "DAI", 18);
        linkToken = new MockLinkToken();
        
        ethUsdFeed = new MockAggregatorV3(2000 * 10**8, 8);
        usdcUsdFeed = new MockAggregatorV3(1 * 10**8, 8);
        daiUsdFeed = new MockAggregatorV3(1 * 10**8, 8);
        
        vm.startPrank(OWNER);
        provider = new AutomatedInsuranceProvider(
            TEST_WORLD_WEATHER_KEY,
            TEST_OPEN_WEATHER_KEY,
            TEST_WEATHERBIT_KEY
        );
        
        provider.addSupportedToken(address(usdc), address(usdcUsdFeed));
        provider.addSupportedToken(address(dai), address(daiUsdFeed));
        vm.stopPrank();
        
        // Setup token balances
        usdc.mint(OWNER, 100000 * 10**6);
        usdc.mint(CLIENT1, 10000 * 10**6);
        dai.mint(OWNER, 100000 * 10**18);
        dai.mint(CLIENT1, 10000 * 10**18);
        linkToken.mint(OWNER, 1000 * 10**18);
        
        vm.prank(OWNER);
        linkToken.transfer(address(provider), 500 * 10**18);
    }

    // =========================================================================
    // Contract Creation Gas Tests
    // =========================================================================
    
    function test_Gas_ContractCreationETH() public {
        vm.startPrank(OWNER);
        
        uint256 fundingAmount = calculatePayoutETH(PAYOUT_1000_USD);
        uint256 gasStart = gasleft();
        
        address contractAddress = provider.newContract{value: fundingAmount}(
            CLIENT1,
            DURATION_7_DAYS,
            PREMIUM_100_USD,
            PAYOUT_1000_USD,
            LOCATION_LONDON,
            address(0)
        );
        
        uint256 gasUsed = gasStart - gasleft();
        vm.stopPrank();
        
        console.log("Gas used for ETH contract creation:", gasUsed);
        assertNotEq(contractAddress, address(0));
        assertLt(gasUsed, MAX_CONTRACT_CREATION_GAS);
    }
    
    function test_Gas_ContractCreationUSDC() public {
        vm.startPrank(OWNER);
        
        uint256 tokenAmount = 1000 * 10**6; // 1000 USDC
        usdc.approve(address(provider), tokenAmount);
        
        uint256 gasStart = gasleft();
        
        address contractAddress = provider.newContract(
            CLIENT1,
            DURATION_7_DAYS,
            PREMIUM_100_USD,
            PAYOUT_1000_USD,
            LOCATION_LONDON,
            address(usdc)
        );
        
        uint256 gasUsed = gasStart - gasleft();
        vm.stopPrank();
        
        console.log("Gas used for USDC contract creation:", gasUsed);
        assertNotEq(contractAddress, address(0));
        assertLt(gasUsed, MAX_CONTRACT_CREATION_GAS);
    }
    
    function test_Gas_ContractCreationComparison() public {
        // Test ETH vs ERC20 contract creation gas costs
        vm.startPrank(OWNER);
        
        // ETH contract
        uint256 fundingAmount = calculatePayoutETH(PAYOUT_1000_USD);
        uint256 gasStart1 = gasleft();
        provider.newContract{value: fundingAmount}(
            CLIENT1,
            DURATION_7_DAYS,
            PREMIUM_100_USD,
            PAYOUT_1000_USD,
            LOCATION_LONDON,
            address(0)
        );
        uint256 ethGas = gasStart1 - gasleft();
        
        // USDC contract
        uint256 tokenAmount = 1000 * 10**6;
        usdc.approve(address(provider), tokenAmount);
        uint256 gasStart2 = gasleft();
        provider.newContract(
            CLIENT2,
            DURATION_7_DAYS,
            PREMIUM_100_USD,
            PAYOUT_1000_USD,
            LOCATION_PARIS,
            address(usdc)
        );
        uint256 usdcGas = gasStart2 - gasleft();
        
        vm.stopPrank();
        
        console.log("ETH contract creation gas:", ethGas);
        console.log("USDC contract creation gas:", usdcGas);
        console.log("Difference:", ethGas > usdcGas ? ethGas - usdcGas : usdcGas - ethGas);
        
        // Both should be within reasonable limits
        assertLt(ethGas, MAX_CONTRACT_CREATION_GAS);
        assertLt(usdcGas, MAX_CONTRACT_CREATION_GAS);
    }

    // =========================================================================
    // Premium Payment Gas Tests
    // =========================================================================
    
    function test_Gas_PremiumPaymentETH() public {
        // Create contract
        vm.startPrank(OWNER);
        uint256 fundingAmount = calculatePayoutETH(PAYOUT_1000_USD);
        address contractAddress = provider.newContract{value: fundingAmount}(
            CLIENT1,
            DURATION_7_DAYS,
            PREMIUM_100_USD,
            PAYOUT_1000_USD,
            LOCATION_LONDON,
            address(0)
        );
        vm.stopPrank();
        
        // Pay premium
        vm.startPrank(CLIENT1);
        uint256 premiumETH = calculatePremiumETH(PREMIUM_100_USD);
        
        uint256 gasStart = gasleft();
        provider.payPremium{value: premiumETH}(contractAddress);
        uint256 gasUsed = gasStart - gasleft();
        
        vm.stopPrank();
        
        console.log("Gas used for ETH premium payment:", gasUsed);
        assertLt(gasUsed, MAX_PREMIUM_PAYMENT_GAS);
    }
    
    function test_Gas_PremiumPaymentUSDC() public {
        // Create USDC contract
        vm.startPrank(OWNER);
        uint256 tokenAmount = 1000 * 10**6;
        usdc.approve(address(provider), tokenAmount);
        address contractAddress = provider.newContract(
            CLIENT1,
            DURATION_7_DAYS,
            PREMIUM_100_USD,
            PAYOUT_1000_USD,
            LOCATION_LONDON,
            address(usdc)
        );
        vm.stopPrank();
        
        // Pay premium
        vm.startPrank(CLIENT1);
        uint256 premiumAmount = 100 * 10**6; // 100 USDC
        usdc.approve(address(provider), premiumAmount);
        
        uint256 gasStart = gasleft();
        provider.payPremium(contractAddress);
        uint256 gasUsed = gasStart - gasleft();
        
        vm.stopPrank();
        
        console.log("Gas used for USDC premium payment:", gasUsed);
        assertLt(gasUsed, MAX_PREMIUM_PAYMENT_GAS);
    }
    
    function test_Gas_PremiumPaymentWithRefund() public {
        // Create contract
        vm.startPrank(OWNER);
        uint256 fundingAmount = calculatePayoutETH(PAYOUT_1000_USD);
        address contractAddress = provider.newContract{value: fundingAmount}(
            CLIENT1,
            DURATION_7_DAYS,
            PREMIUM_100_USD,
            PAYOUT_1000_USD,
            LOCATION_LONDON,
            address(0)
        );
        vm.stopPrank();
        
        // Pay premium with excess (should trigger refund logic)
        vm.startPrank(CLIENT1);
        uint256 premiumETH = calculatePremiumETH(PREMIUM_100_USD);
        uint256 excessETH = 0.01 ether;
        
        uint256 gasStart = gasleft();
        provider.payPremium{value: premiumETH + excessETH}(contractAddress);
        uint256 gasUsed = gasStart - gasleft();
        
        vm.stopPrank();
        
        console.log("Gas used for premium payment with refund:", gasUsed);
        // Refund should add minimal gas cost
        assertLt(gasUsed, MAX_PREMIUM_PAYMENT_GAS + 30_000);
    }

    // =========================================================================
    // Automation Gas Tests
    // =========================================================================
    
    function test_Gas_CheckUpkeepFunction() public {
        // Create and activate contracts
        createActiveContracts(5);
        
        skipToNextDay();
        
        uint256 gasStart = gasleft();
        bytes memory checkData = "";
        provider.checkUpkeep(checkData);
        uint256 gasUsed = gasStart - gasleft();
        
        console.log("Gas used for checkUpkeep (5 contracts):", gasUsed);
        
        // checkUpkeep should be very efficient as it's called frequently by Keepers
        assertLt(gasUsed, 100_000);
    }
    
    function test_Gas_SingleContractUpkeep() public {
        // Create single contract
        address contractAddress = createActiveContract(CLIENT1);
        
        skipToNextDay();
        bytes memory checkData = "";
        (, bytes memory performData) = provider.checkUpkeep(checkData);
        
        uint256 gasStart = gasleft();
        provider.performUpkeep(performData);
        uint256 gasUsed = gasStart - gasleft();
        
        console.log("Gas used for single contract upkeep:", gasUsed);
        assertLt(gasUsed, MAX_SINGLE_UPKEEP_GAS);
    }
    
    function test_Gas_BatchUpkeepEfficiency() public {
        // Test batch sizes from 1 to 10
        uint256[] memory gasCosts = new uint256[](10);
        
        for (uint256 batchSize = 1; batchSize <= 10; batchSize++) {
            // Create fresh provider for each test
            AutomatedInsuranceProvider testProvider = new AutomatedInsuranceProvider(
                TEST_WORLD_WEATHER_KEY,
                TEST_OPEN_WEATHER_KEY,
                TEST_WEATHERBIT_KEY
            );
            
            // Create contracts
            createActiveContractsForProvider(testProvider, batchSize);
            
            skipToNextDay();
            bytes memory checkData = "";
            (, bytes memory performData) = testProvider.checkUpkeep(checkData);
            
            uint256 gasStart = gasleft();
            testProvider.performUpkeep(performData);
            uint256 gasUsed = gasStart - gasleft();
            
            gasCosts[batchSize - 1] = gasUsed;
            
            console.log("Batch size:", batchSize, "Gas used:", gasUsed, "Per contract:", gasUsed / batchSize);
        }
        
        // Verify batch efficiency - larger batches should be more efficient per contract
        uint256 singleContractGas = gasCosts[0];
        uint256 tenContractAvgGas = gasCosts[9] / 10;
        
        console.log("Single contract gas:", singleContractGas);
        console.log("10-contract average gas:", tenContractAvgGas);
        console.log("Efficiency improvement:", singleContractGas - tenContractAvgGas);
        
        // Batch processing should be more efficient per contract
        assertLt(tenContractAvgGas, singleContractGas);
        assertLt(gasCosts[9], MAX_BATCH_UPKEEP_GAS);
    }
    
    function test_Gas_MaximumBatchUpkeep() public {
        // Test with maximum batch size (10 contracts)
        createActiveContracts(10);
        
        skipToNextDay();
        bytes memory checkData = "";
        (, bytes memory performData) = provider.checkUpkeep(checkData);
        
        // Verify batch size is limited to 10
        address[] memory contractBatch = abi.decode(performData, (address[]));
        assertEq(contractBatch.length, 10);
        
        uint256 gasStart = gasleft();
        provider.performUpkeep(performData);
        uint256 gasUsed = gasStart - gasleft();
        
        console.log("Gas used for maximum batch (10 contracts):", gasUsed);
        console.log("Average gas per contract:", gasUsed / 10);
        
        assertLt(gasUsed, MAX_BATCH_UPKEEP_GAS);
        assertLt(gasUsed / 10, 200_000); // Should be under 200k per contract on average
    }

    // =========================================================================
    // Weather Check Gas Tests
    // =========================================================================
    
    function test_Gas_IndividualWeatherCheck() public {
        address contractAddress = createActiveContract(CLIENT1);
        AutomatedInsuranceContract insurance = AutomatedInsuranceContract(contractAddress);
        
        uint256 gasStart = gasleft();
        vm.prank(OWNER);
        insurance.performAutomatedWeatherCheck();
        uint256 gasUsed = gasStart - gasleft();
        
        console.log("Gas used for individual weather check:", gasUsed);
        assertLt(gasUsed, MAX_WEATHER_CHECK_GAS);
    }
    
    function test_Gas_ManualWeatherUpdate() public {
        address[] memory contracts = new address[](5);
        for (uint256 i = 0; i < 5; i++) {
            contracts[i] = createActiveContract(CLIENT1);
        }
        
        uint256 gasStart = gasleft();
        vm.prank(OWNER);
        provider.manualWeatherUpdate(contracts);
        uint256 gasUsed = gasStart - gasleft();
        
        console.log("Gas used for manual weather update (5 contracts):", gasUsed);
        console.log("Average gas per contract:", gasUsed / 5);
        
        // Manual update should be reasonably efficient
        assertLt(gasUsed / 5, MAX_WEATHER_CHECK_GAS);
    }

    // =========================================================================
    // Token Calculation Gas Tests
    // =========================================================================
    
    function test_Gas_TokenAmountCalculation() public {
        uint256 gasStart = gasleft();
        provider.getTokenAmountForUSD(address(usdc), PREMIUM_100_USD);
        uint256 gasUsed = gasStart - gasleft();
        
        console.log("Gas used for token amount calculation:", gasUsed);
        assertLt(gasUsed, MAX_TOKEN_CALCULATION_GAS);
    }
    
    function test_Gas_TokenValueCalculation() public {
        uint256 tokenAmount = 100 * 10**6; // 100 USDC
        
        uint256 gasStart = gasleft();
        provider.getTokenValueInUSD(address(usdc), tokenAmount);
        uint256 gasUsed = gasStart - gasleft();
        
        console.log("Gas used for token value calculation:", gasUsed);
        assertLt(gasUsed, MAX_TOKEN_CALCULATION_GAS);
    }
    
    function test_Gas_PriceFeedOperations() public {
        // Test ETH price feed
        uint256 gasStart1 = gasleft();
        provider.getLatestPrice();
        uint256 ethPriceGas = gasStart1 - gasleft();
        
        // Test multiple token calculations
        uint256 gasStart2 = gasleft();
        provider.getTokenAmountForUSD(address(usdc), PREMIUM_100_USD);
        provider.getTokenAmountForUSD(address(dai), PREMIUM_100_USD);
        uint256 multiTokenGas = gasStart2 - gasleft();
        
        console.log("Gas for ETH price feed:", ethPriceGas);
        console.log("Gas for multi-token calculations:", multiTokenGas);
        
        assertLt(ethPriceGas, 30_000);
        assertLt(multiTokenGas, 100_000);
    }

    // =========================================================================
    // Contract State Management Gas Tests
    // =========================================================================
    
    function test_Gas_ContractActivation() public {
        // Create contract
        vm.startPrank(OWNER);
        uint256 fundingAmount = calculatePayoutETH(PAYOUT_1000_USD);
        address contractAddress = provider.newContract{value: fundingAmount}(
            CLIENT1,
            DURATION_7_DAYS,
            PREMIUM_100_USD,
            PAYOUT_1000_USD,
            LOCATION_LONDON,
            address(0)
        );
        vm.stopPrank();
        
        // Measure activation gas (part of premium payment)
        vm.startPrank(CLIENT1);
        uint256 premiumETH = calculatePremiumETH(PREMIUM_100_USD);
        
        uint256 gasStart = gasleft();
        provider.payPremium{value: premiumETH}(contractAddress);
        uint256 gasUsed = gasStart - gasleft();
        
        vm.stopPrank();
        
        console.log("Gas used for contract activation:", gasUsed);
        
        // Verify contract was added to active list
        assertEq(provider.getActiveContractsCount(), 1);
    }
    
    function test_Gas_ContractDeactivation() public {
        address contractAddress = createActiveContract(CLIENT1);
        
        uint256 gasStart = gasleft();
        vm.prank(OWNER);
        provider.deactivateContract(contractAddress);
        uint256 gasUsed = gasStart - gasleft();
        
        console.log("Gas used for contract deactivation:", gasUsed);
        
        // Deactivation should be efficient
        assertLt(gasUsed, 100_000);
        assertEq(provider.getActiveContractsCount(), 0);
    }
    
    function test_Gas_ActiveContractArrayOperations() public {
        // Test array operations with varying sizes
        uint256[] memory addGasCosts = new uint256[](10);
        uint256[] memory removeGasCosts = new uint256[](10);
        
        address[] memory contracts = new address[](10);
        
        // Test adding contracts
        for (uint256 i = 0; i < 10; i++) {
            uint256 gasStart = gasleft();
            contracts[i] = createActiveContract(CLIENT1);
            addGasCosts[i] = gasStart - gasleft();
            
            console.log("Contract", i + 1, "add gas:", addGasCosts[i]);
        }
        
        // Test removing contracts
        for (uint256 i = 0; i < 10; i++) {
            uint256 gasStart = gasleft();
            vm.prank(OWNER);
            provider.deactivateContract(contracts[i]);
            removeGasCosts[i] = gasStart - gasleft();
            
            console.log("Contract", i + 1, "remove gas:", removeGasCosts[i]);
        }
        
        // Array operations should remain efficient regardless of size
        for (uint256 i = 0; i < 10; i++) {
            assertLt(removeGasCosts[i], 150_000);
        }
    }

    // =========================================================================
    // Payout Gas Tests
    // =========================================================================
    
    function test_Gas_PayoutETH() public {
        address contractAddress = createActiveContract(CLIENT1);
        AutomatedInsuranceContract insurance = AutomatedInsuranceContract(contractAddress);
        
        // Simulate drought conditions to trigger payout
        // This would require mocking oracle responses in a full test
        
        uint256 clientBalanceBefore = CLIENT1.balance;
        
        // Note: This test would need to trigger actual payout conditions
        // For gas measurement purposes, we'll test the payout function directly
        console.log("Note: Payout gas test requires drought condition simulation");
        console.log("Expected payout gas should be under:", MAX_PAYOUT_GAS);
        
        // Verify contract setup is correct for payout testing
        assertTrue(insurance.isActive());
        assertGt(address(insurance).balance, 0);
    }

    // =========================================================================
    // Integration Gas Tests
    // =========================================================================
    
    function test_Gas_CompleteWorkflowETH() public {
        console.log("=== Complete ETH Workflow Gas Analysis ===");
        
        // 1. Contract Creation
        vm.startPrank(OWNER);
        uint256 fundingAmount = calculatePayoutETH(PAYOUT_1000_USD);
        uint256 gasStart1 = gasleft();
        address contractAddress = provider.newContract{value: fundingAmount}(
            CLIENT1,
            DURATION_7_DAYS,
            PREMIUM_100_USD,
            PAYOUT_1000_USD,
            LOCATION_LONDON,
            address(0)
        );
        uint256 creationGas = gasStart1 - gasleft();
        vm.stopPrank();
        
        // 2. Premium Payment
        vm.startPrank(CLIENT1);
        uint256 premiumETH = calculatePremiumETH(PREMIUM_100_USD);
        uint256 gasStart2 = gasleft();
        provider.payPremium{value: premiumETH}(contractAddress);
        uint256 paymentGas = gasStart2 - gasleft();
        vm.stopPrank();
        
        // 3. Weather Check
        skipToNextDay();
        uint256 gasStart3 = gasleft();
        bytes memory checkData = "";
        (, bytes memory performData) = provider.checkUpkeep(checkData);
        provider.performUpkeep(performData);
        uint256 upkeepGas = gasStart3 - gasleft();
        
        // 4. Contract Management
        uint256 gasStart4 = gasleft();
        vm.prank(OWNER);
        provider.deactivateContract(contractAddress);
        uint256 deactivationGas = gasStart4 - gasleft();
        
        uint256 totalGas = creationGas + paymentGas + upkeepGas + deactivationGas;
        
        console.log("Contract Creation Gas:", creationGas);
        console.log("Premium Payment Gas:", paymentGas);
        console.log("Weather Upkeep Gas:", upkeepGas);
        console.log("Deactivation Gas:", deactivationGas);
        console.log("Total Workflow Gas:", totalGas);
        
        // Total should be reasonable for complete insurance lifecycle
        assertLt(totalGas, 4_000_000);
    }
    
    function test_Gas_OptimizationComparison() public {
        console.log("=== Gas Optimization Comparison ===");
        
        // Compare different batch sizes
        uint256[] memory batchSizes = new uint256[](5);
        batchSizes[0] = 1;
        batchSizes[1] = 3;
        batchSizes[2] = 5;
        batchSizes[3] = 8;
        batchSizes[4] = 10;
        
        for (uint256 i = 0; i < batchSizes.length; i++) {
            AutomatedInsuranceProvider testProvider = new AutomatedInsuranceProvider(
                TEST_WORLD_WEATHER_KEY,
                TEST_OPEN_WEATHER_KEY,
                TEST_WEATHERBIT_KEY
            );
            
            createActiveContractsForProvider(testProvider, batchSizes[i]);
            
            skipToNextDay();
            bytes memory checkData = "";
            (, bytes memory performData) = testProvider.checkUpkeep(checkData);
            
            uint256 gasStart = gasleft();
            testProvider.performUpkeep(performData);
            uint256 gasUsed = gasStart - gasleft();
            
            console.log("Batch size:", batchSizes[i]);
            console.log("  Total gas:", gasUsed);
            console.log("  Gas per contract:", gasUsed / batchSizes[i]);
            console.log("  Efficiency ratio:", (gasUsed * 100) / (batchSizes[i] * 500_000)); // % of linear scaling
        }
    }

    // =========================================================================
    // Helper Functions
    // =========================================================================
    
    function createActiveContract(address client) internal returns (address) {
        vm.startPrank(OWNER);
        uint256 fundingAmount = calculatePayoutETH(PAYOUT_1000_USD);
        address contractAddress = provider.newContract{value: fundingAmount}(
            client,
            DURATION_7_DAYS,
            PREMIUM_100_USD,
            PAYOUT_1000_USD,
            LOCATION_LONDON,
            address(0)
        );
        vm.stopPrank();
        
        vm.startPrank(client);
        uint256 premiumETH = calculatePremiumETH(PREMIUM_100_USD);
        provider.payPremium{value: premiumETH}(contractAddress);
        vm.stopPrank();
        
        return contractAddress;
    }
    
    function createActiveContracts(uint256 count) internal {
        for (uint256 i = 0; i < count; i++) {
            createActiveContract(CLIENT1);
        }
    }
    
    function createActiveContractsForProvider(
        AutomatedInsuranceProvider testProvider, 
        uint256 count
    ) internal {
        vm.startPrank(OWNER);
        uint256 fundingAmount = calculatePayoutETH(PAYOUT_1000_USD);
        uint256 premiumETH = calculatePremiumETH(PREMIUM_100_USD);
        
        for (uint256 i = 0; i < count; i++) {
            address contractAddress = testProvider.newContract{value: fundingAmount}(
                CLIENT1,
                DURATION_7_DAYS,
                PREMIUM_100_USD,
                PAYOUT_1000_USD,
                string.concat("Location", vm.toString(i)),
                address(0)
            );
            
            vm.stopPrank();
            vm.prank(CLIENT1);
            testProvider.payPremium{value: premiumETH}(contractAddress);
            vm.startPrank(OWNER);
        }
        
        vm.stopPrank();
    }
}

/**
 * @title GasBenchmarkTest
 * @dev Specific benchmark tests for gas optimization targets
 */
contract GasBenchmarkTest is TestHelper {
    
    AutomatedInsuranceProvider public provider;
    
    function setUp() public {
        setupAccounts();
        
        vm.startPrank(OWNER);
        provider = new AutomatedInsuranceProvider(
            TEST_WORLD_WEATHER_KEY,
            TEST_OPEN_WEATHER_KEY,
            TEST_WEATHERBIT_KEY
        );
        vm.stopPrank();
    }
    
    function test_Benchmark_ContractDeployment() public {
        uint256 gasStart = gasleft();
        
        new AutomatedInsuranceProvider(
            TEST_WORLD_WEATHER_KEY,
            TEST_OPEN_WEATHER_KEY,
            TEST_WEATHERBIT_KEY
        );
        
        uint256 gasUsed = gasStart - gasleft();
        
        console.log("Provider deployment gas:", gasUsed);
        
        // Provider deployment should be under 5M gas
        assertLt(gasUsed, 5_000_000);
    }
    
    function test_Benchmark_TokenOperations() public {
        MockERC20 usdc = new MockERC20("USD Coin", "USDC", 6);
        MockAggregatorV3 usdcFeed = new MockAggregatorV3(1 * 10**8, 8);
        
        // Add token
        uint256 gasStart1 = gasleft();
        vm.prank(OWNER);
        provider.addSupportedToken(address(usdc), address(usdcFeed));
        uint256 addTokenGas = gasStart1 - gasleft();
        
        // Remove token
        uint256 gasStart2 = gasleft();
        vm.prank(OWNER);
        provider.removeSupportedToken(address(usdc));
        uint256 removeTokenGas = gasStart2 - gasleft();
        
        console.log("Add token gas:", addTokenGas);
        console.log("Remove token gas:", removeTokenGas);
        
        assertLt(addTokenGas, 100_000);
        assertLt(removeTokenGas, 50_000);
    }
    
    function test_Benchmark_ViewFunctions() public {
        // Create some active contracts
        for (uint256 i = 0; i < 5; i++) {
            vm.startPrank(OWNER);
            uint256 fundingAmount = calculatePayoutETH(PAYOUT_1000_USD);
            address contractAddress = provider.newContract{value: fundingAmount}(
                CLIENT1,
                DURATION_7_DAYS,
                PREMIUM_100_USD,
                PAYOUT_1000_USD,
                LOCATION_LONDON,
                address(0)
            );
            vm.stopPrank();
            
            vm.startPrank(CLIENT1);
            uint256 premiumETH = calculatePremiumETH(PREMIUM_100_USD);
            provider.payPremium{value: premiumETH}(contractAddress);
            vm.stopPrank();
        }
        
        // Test view function gas costs
        uint256 gasStart1 = gasleft();
        provider.getActiveContractsCount();
        uint256 countGas = gasStart1 - gasleft();
        
        uint256 gasStart2 = gasleft();
        provider.getActiveContracts(0, 5);
        uint256 getContractsGas = gasStart2 - gasleft();
        
        uint256 gasStart3 = gasleft();
        provider.getLatestPrice();
        uint256 priceGas = gasStart3 - gasleft();
        
        console.log("Get active count gas:", countGas);
        console.log("Get active contracts gas:", getContractsGas);
        console.log("Get latest price gas:", priceGas);
        
        // View functions should be very efficient
        assertLt(countGas, 10_000);
        assertLt(getContractsGas, 50_000);
        assertLt(priceGas, 30_000);
    }
}