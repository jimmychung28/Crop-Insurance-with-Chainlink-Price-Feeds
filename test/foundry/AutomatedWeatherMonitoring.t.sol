// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "./utils/TestHelper.sol";
import "./mocks/MockERC20.sol";
import "../../contracts/AutomatedInsurance.sol";

/**
 * @title AutomatedWeatherMonitoringTest
 * @dev Comprehensive tests for Chainlink Automation integration in Solidity
 */
contract AutomatedWeatherMonitoringTest is TestHelper {
    
    AutomatedInsuranceProvider public provider;
    AutomatedInsuranceContract public insurance1;
    AutomatedInsuranceContract public insurance2;
    MockERC20 public usdc;
    MockAggregatorV3 public ethUsdFeed;
    MockAggregatorV3 public usdcUsdFeed;
    MockLinkToken public linkToken;
    MockOracle public oracle1;
    MockOracle public oracle2;
    
    address public contractAddress1;
    address public contractAddress2;
    
    // Test events
    event AutomationUpkeepPerformed(
        uint256 timestamp,
        uint256 contractsProcessed,
        uint256 gasUsed
    );
    
    event ContractActivated(address indexed contractAddress);
    event ContractDeactivated(address indexed contractAddress);
    event AutomatedWeatherCheckPerformed(uint256 timestamp, uint256 rainfall);

    function setUp() public {
        setupAccounts();
        
        // Deploy mock contracts
        usdc = new MockERC20("USD Coin", "USDC", 6);
        linkToken = new MockLinkToken();
        oracle1 = new MockOracle();
        oracle2 = new MockOracle();
        
        // Deploy mock price feeds
        ethUsdFeed = new MockAggregatorV3(2000 * 10**8, 8); // $2000 ETH
        usdcUsdFeed = new MockAggregatorV3(1 * 10**8, 8);   // $1 USDC
        
        // Deploy insurance provider
        vm.startPrank(OWNER);
        provider = new AutomatedInsuranceProvider(
            TEST_WORLD_WEATHER_KEY,
            TEST_OPEN_WEATHER_KEY,
            TEST_WEATHERBIT_KEY
        );
        
        // Setup supported tokens
        provider.addSupportedToken(address(usdc), address(usdcUsdFeed));
        vm.stopPrank();
        
        // Mint tokens and setup balances
        usdc.mint(OWNER, 10000 * 10**6);
        usdc.mint(CLIENT1, 1000 * 10**6);
        usdc.mint(CLIENT2, 1000 * 10**6);
        linkToken.mint(OWNER, 100 * 10**18);
        
        // Transfer LINK to provider
        vm.prank(OWNER);
        linkToken.transfer(address(provider), 50 * 10**18);
        
        // Create test contracts
        createTestContracts();
    }
    
    function createTestContracts() internal {
        vm.startPrank(OWNER);
        
        // Create contract 1
        uint256 fundingAmount = calculatePayoutETH(PAYOUT_1000_USD);
        contractAddress1 = provider.newContract{value: fundingAmount}(
            CLIENT1,
            DURATION_7_DAYS,
            PREMIUM_100_USD,
            PAYOUT_1000_USD,
            LOCATION_LONDON,
            address(0) // ETH
        );
        
        // Create contract 2
        contractAddress2 = provider.newContract{value: fundingAmount}(
            CLIENT2,
            DURATION_7_DAYS,
            PREMIUM_100_USD,
            PAYOUT_1000_USD,
            LOCATION_PARIS,
            address(0) // ETH
        );
        
        vm.stopPrank();
        
        insurance1 = AutomatedInsuranceContract(contractAddress1);
        insurance2 = AutomatedInsuranceContract(contractAddress2);
        
        // Pay premiums to activate contracts
        uint256 premiumETH = calculatePremiumETH(PREMIUM_100_USD);
        
        vm.prank(CLIENT1);
        provider.payPremium{value: premiumETH}(contractAddress1);
        
        vm.prank(CLIENT2);
        provider.payPremium{value: premiumETH}(contractAddress2);
    }

    // =========================================================================
    // Chainlink Automation Interface Tests
    // =========================================================================
    
    function test_CheckUpkeepWhenNotNeeded() public {
        // Check upkeep immediately after creation (should be false)
        bytes memory checkData = "";
        (bool upkeepNeeded, bytes memory performData) = provider.checkUpkeep(checkData);
        
        assertFalse(upkeepNeeded);
        assertEq(performData.length, 0);
    }
    
    function test_CheckUpkeepWhenNeeded() public {
        // Advance time to trigger upkeep
        skipToNextDay();
        
        bytes memory checkData = "";
        (bool upkeepNeeded, bytes memory performData) = provider.checkUpkeep(checkData);
        
        assertTrue(upkeepNeeded);
        assertGt(performData.length, 0);
        
        // Decode perform data to verify it contains contract addresses
        address[] memory contractBatch = abi.decode(performData, (address[]));
        assertEq(contractBatch.length, 2);
        
        bool found1 = false;
        bool found2 = false;
        for (uint256 i = 0; i < contractBatch.length; i++) {
            if (contractBatch[i] == contractAddress1) found1 = true;
            if (contractBatch[i] == contractAddress2) found2 = true;
        }
        assertTrue(found1 && found2);
    }
    
    function test_CheckUpkeepWhenAutomationDisabled() public {
        // Disable automation
        vm.prank(OWNER);
        provider.setAutomationEnabled(false);
        
        // Advance time
        skipToNextDay();
        
        bytes memory checkData = "";
        (bool upkeepNeeded,) = provider.checkUpkeep(checkData);
        
        assertFalse(upkeepNeeded);
    }
    
    function test_CheckUpkeepWhenNoActiveContracts() public {
        // Deactivate all contracts
        vm.prank(OWNER);
        provider.deactivateContract(contractAddress1);
        vm.prank(OWNER);
        provider.deactivateContract(contractAddress2);
        
        // Advance time
        skipToNextDay();
        
        bytes memory checkData = "";
        (bool upkeepNeeded,) = provider.checkUpkeep(checkData);
        
        assertFalse(upkeepNeeded);
    }
    
    function test_PerformUpkeepSuccessfully() public {
        // Advance time to trigger upkeep
        skipToNextDay();
        
        // Get upkeep data
        bytes memory checkData = "";
        (bool upkeepNeeded, bytes memory performData) = provider.checkUpkeep(checkData);
        assertTrue(upkeepNeeded);
        
        // Record timestamp before upkeep
        uint256 timestampBefore = provider.lastUpkeepTimestamp();
        
        // Perform upkeep
        vm.expectEmit(true, false, false, false);
        emit AutomationUpkeepPerformed(block.timestamp, 2, 0); // gasUsed will vary
        
        provider.performUpkeep(performData);
        
        // Verify last upkeep timestamp was updated
        uint256 timestampAfter = provider.lastUpkeepTimestamp();
        assertGt(timestampAfter, timestampBefore);
        assertEq(timestampAfter, block.timestamp);
    }
    
    function test_RevertPerformUpkeepWhenNotNeeded() public {
        // Try to perform upkeep without enough time passing
        bytes memory emptyBatch = abi.encode(new address[](0));
        
        vm.expectRevert("Upkeep not needed");
        provider.performUpkeep(emptyBatch);
    }
    
    function test_RevertPerformUpkeepWhenAutomationDisabled() public {
        // Disable automation
        vm.prank(OWNER);
        provider.setAutomationEnabled(false);
        
        // Try to perform upkeep
        skipToNextDay();
        bytes memory emptyBatch = abi.encode(new address[](0));
        
        vm.expectRevert("Automation disabled");
        provider.performUpkeep(emptyBatch);
    }

    // =========================================================================
    // Individual Contract Weather Monitoring Tests
    // =========================================================================
    
    function test_ContractNeedsWeatherUpdate() public {
        // Contract should need update initially
        assertTrue(insurance1.needsWeatherUpdate());
        assertTrue(insurance2.needsWeatherUpdate());
    }
    
    function test_PerformAutomatedWeatherCheck() public {
        // Verify contract needs update
        assertTrue(insurance1.needsWeatherUpdate());
        
        // Perform weather check
        vm.expectEmit(true, false, false, false);
        emit AutomatedWeatherCheckPerformed(block.timestamp, 0); // rainfall will vary
        
        vm.prank(OWNER);
        insurance1.performAutomatedWeatherCheck();
        
        // Contract should no longer need immediate update
        assertFalse(insurance1.needsWeatherUpdate());
    }
    
    function test_RevertWeatherCheckTooSoon() public {
        // Perform first weather check
        vm.prank(OWNER);
        insurance1.performAutomatedWeatherCheck();
        
        // Try to perform another check immediately
        vm.startPrank(OWNER);
        vm.expectRevert("Too soon for weather check");
        insurance1.performAutomatedWeatherCheck();
        vm.stopPrank();
    }
    
    function test_WeatherCheckAfterTimeDelay() public {
        // Perform first weather check
        vm.prank(OWNER);
        insurance1.performAutomatedWeatherCheck();
        
        // Should not need update immediately
        assertFalse(insurance1.needsWeatherUpdate());
        
        // Advance time and check again
        skipToNextDay();
        assertTrue(insurance1.needsWeatherUpdate());
        
        // Should be able to perform check again
        vm.prank(OWNER);
        insurance1.performAutomatedWeatherCheck();
    }
    
    function test_ContractEndsAutomaticallyWhenExpired() public {
        // Advance time past contract duration
        skipTime(DURATION_7_DAYS + 1);
        
        // Verify contract needs update (for end check)
        assertTrue(insurance1.needsWeatherUpdate());
        
        // Perform weather check - should trigger contract end
        vm.prank(OWNER);
        insurance1.performAutomatedWeatherCheck();
        
        // Contract should no longer be active
        assertFalse(insurance1.isActive());
    }

    // =========================================================================
    // Batch Processing Tests
    // =========================================================================
    
    function test_BatchProcessingMultipleContracts() public {
        // Verify both contracts are active
        assertEq(provider.getActiveContractsCount(), 2);
        
        // Advance time to trigger upkeep
        skipToNextDay();
        
        // Get upkeep data and perform upkeep
        bytes memory checkData = "";
        (, bytes memory performData) = provider.checkUpkeep(checkData);
        
        // Perform upkeep should process both contracts
        vm.expectEmit(true, false, false, false);
        emit AutomationUpkeepPerformed(block.timestamp, 2, 0);
        
        provider.performUpkeep(performData);
        
        // Both contracts should no longer need updates
        assertFalse(insurance1.needsWeatherUpdate());
        assertFalse(insurance2.needsWeatherUpdate());
    }
    
    function test_BatchSizeLimit() public {
        // Create more contracts to test batch limit
        vm.startPrank(OWNER);
        
        address[] memory extraContracts = new address[](15);
        uint256 fundingAmount = calculatePayoutETH(PAYOUT_1000_USD);
        uint256 premiumETH = calculatePremiumETH(PREMIUM_100_USD);
        
        // Create 15 additional contracts (17 total)
        for (uint256 i = 0; i < 15; i++) {
            extraContracts[i] = provider.newContract{value: fundingAmount}(
                CLIENT1,
                DURATION_7_DAYS,
                PREMIUM_100_USD,
                PAYOUT_1000_USD,
                string.concat("Location", vm.toString(i)),
                address(0)
            );
            
            // Activate each contract
            vm.stopPrank();
            vm.prank(CLIENT1);
            provider.payPremium{value: premiumETH}(extraContracts[i]);
            vm.startPrank(OWNER);
        }
        
        vm.stopPrank();
        
        // Should have 17 active contracts
        assertEq(provider.getActiveContractsCount(), 17);
        
        // Advance time and check upkeep
        skipToNextDay();
        bytes memory checkData = "";
        (bool upkeepNeeded, bytes memory performData) = provider.checkUpkeep(checkData);
        
        assertTrue(upkeepNeeded);
        
        // Decode and verify batch size is limited to 10
        address[] memory contractBatch = abi.decode(performData, (address[]));
        assertEq(contractBatch.length, 10); // MAX_CONTRACTS_PER_BATCH
        
        // Perform upkeep should process exactly 10 contracts
        vm.expectEmit(true, false, false, false);
        emit AutomationUpkeepPerformed(block.timestamp, 10, 0);
        
        provider.performUpkeep(performData);
    }
    
    function test_ActiveContractManagement() public {
        // Initial count
        assertEq(provider.getActiveContractsCount(), 2);
        
        // Deactivate one contract
        vm.expectEmit(true, false, false, false);
        emit ContractDeactivated(contractAddress1);
        
        vm.prank(OWNER);
        provider.deactivateContract(contractAddress1);
        
        // Count should decrease
        assertEq(provider.getActiveContractsCount(), 1);
        
        // Get active contracts
        address[] memory activeContracts = provider.getActiveContracts(0, 10);
        assertEq(activeContracts.length, 1);
        assertEq(activeContracts[0], contractAddress2);
    }
    
    function test_GetActiveContractsPagination() public {
        // Create additional contracts for pagination test
        vm.startPrank(OWNER);
        
        uint256 fundingAmount = calculatePayoutETH(PAYOUT_1000_USD);
        uint256 premiumETH = calculatePremiumETH(PREMIUM_100_USD);
        
        // Create 3 more contracts (5 total)
        for (uint256 i = 0; i < 3; i++) {
            address newContract = provider.newContract{value: fundingAmount}(
                CLIENT1,
                DURATION_7_DAYS,
                PREMIUM_100_USD,
                PAYOUT_1000_USD,
                string.concat("Location", vm.toString(i + 3)),
                address(0)
            );
            
            vm.stopPrank();
            vm.prank(CLIENT1);
            provider.payPremium{value: premiumETH}(newContract);
            vm.startPrank(OWNER);
        }
        
        vm.stopPrank();
        
        // Test pagination
        assertEq(provider.getActiveContractsCount(), 5);
        
        // Get first 2 contracts
        address[] memory batch1 = provider.getActiveContracts(0, 2);
        assertEq(batch1.length, 2);
        
        // Get next 2 contracts
        address[] memory batch2 = provider.getActiveContracts(2, 2);
        assertEq(batch2.length, 2);
        
        // Get remaining contract
        address[] memory batch3 = provider.getActiveContracts(4, 2);
        assertEq(batch3.length, 1);
    }

    // =========================================================================
    // Error Handling Tests
    // =========================================================================
    
    function test_HandleContractBecomeInactiveDuringBatch() public {
        // Advance time to trigger upkeep
        skipToNextDay();
        
        // Get upkeep data
        bytes memory checkData = "";
        (, bytes memory performData) = provider.checkUpkeep(checkData);
        
        // Deactivate one contract right before upkeep
        vm.prank(OWNER);
        provider.deactivateContract(contractAddress1);
        
        // Upkeep should still work (will skip inactive contract)
        // Should process 1 contract (contract2) instead of 2
        vm.expectEmit(true, false, false, false);
        emit AutomationUpkeepPerformed(block.timestamp, 1, 0);
        
        provider.performUpkeep(performData);
    }
    
    function test_HandleEmptyContractBatch() public {
        // Deactivate all contracts
        vm.prank(OWNER);
        provider.deactivateContract(contractAddress1);
        vm.prank(OWNER);
        provider.deactivateContract(contractAddress2);
        
        // Advance time
        skipToNextDay();
        
        // Should not need upkeep with no active contracts
        bytes memory checkData = "";
        (bool upkeepNeeded,) = provider.checkUpkeep(checkData);
        assertFalse(upkeepNeeded);
    }
    
    function test_RevertGetActiveContractsOutOfBounds() public {
        uint256 activeCount = provider.getActiveContractsCount();
        
        // Try to start beyond available contracts
        vm.expectRevert("Start index out of bounds");
        provider.getActiveContracts(activeCount + 1, 1);
    }

    // =========================================================================
    // Manual Override Tests
    // =========================================================================
    
    function test_ManualWeatherUpdate() public {
        address[] memory contractsToUpdate = createAddressArray(contractAddress1);
        
        vm.prank(OWNER);
        provider.manualWeatherUpdate(contractsToUpdate);
        
        // Contract should no longer need update
        assertFalse(insurance1.needsWeatherUpdate());
    }
    
    function test_ManualWeatherUpdateMultipleContracts() public {
        address[] memory contractsToUpdate = createAddressArray(contractAddress1, contractAddress2);
        
        vm.prank(OWNER);
        provider.manualWeatherUpdate(contractsToUpdate);
        
        // Both contracts should no longer need updates
        assertFalse(insurance1.needsWeatherUpdate());
        assertFalse(insurance2.needsWeatherUpdate());
    }
    
    function test_RevertManualUpdateByNonOwner() public {
        address[] memory contractsToUpdate = createAddressArray(contractAddress1);
        
        vm.startPrank(CLIENT1);
        vm.expectRevert("Ownable: caller is not the owner");
        provider.manualWeatherUpdate(contractsToUpdate);
        vm.stopPrank();
    }
    
    function test_SetAutomationEnabled() public {
        // Initially enabled
        assertTrue(provider.automationEnabled());
        
        // Disable automation
        vm.prank(OWNER);
        provider.setAutomationEnabled(false);
        assertFalse(provider.automationEnabled());
        
        // Re-enable automation
        vm.prank(OWNER);
        provider.setAutomationEnabled(true);
        assertTrue(provider.automationEnabled());
    }
    
    function test_SetUpkeepInterval() public {
        uint256 initialInterval = provider.upkeepInterval();
        uint256 newInterval = 2 * DAY_IN_SECONDS; // 2 days
        
        vm.prank(OWNER);
        provider.setUpkeepInterval(newInterval);
        
        assertEq(provider.upkeepInterval(), newInterval);
        assertNotEq(provider.upkeepInterval(), initialInterval);
    }
    
    function test_RevertSetUpkeepIntervalTooShort() public {
        uint256 tooShort = 3000; // 50 minutes
        
        vm.startPrank(OWNER);
        vm.expectRevert("Minimum 1 hour interval");
        provider.setUpkeepInterval(tooShort);
        vm.stopPrank();
    }
    
    function test_RevertAutomationControlsByNonOwner() public {
        vm.startPrank(CLIENT1);
        
        vm.expectRevert("Ownable: caller is not the owner");
        provider.setAutomationEnabled(false);
        
        vm.expectRevert("Ownable: caller is not the owner");
        provider.setUpkeepInterval(2 * DAY_IN_SECONDS);
        
        vm.stopPrank();
    }

    // =========================================================================
    // Integration Tests
    // =========================================================================
    
    function test_CompleteAutomationLifecycle() public {
        // 1. Verify initial state
        assertEq(provider.getActiveContractsCount(), 2);
        assertTrue(insurance1.needsWeatherUpdate());
        assertTrue(insurance2.needsWeatherUpdate());
        
        // 2. First automated upkeep
        skipToNextDay();
        bytes memory checkData = "";
        (, bytes memory performData) = provider.checkUpkeep(checkData);
        provider.performUpkeep(performData);
        
        // 3. Contracts no longer need updates
        assertFalse(insurance1.needsWeatherUpdate());
        assertFalse(insurance2.needsWeatherUpdate());
        
        // 4. Second day - should need updates again
        skipToNextDay();
        assertTrue(insurance1.needsWeatherUpdate());
        assertTrue(insurance2.needsWeatherUpdate());
        
        // 5. Second automated upkeep
        (, bytes memory performData2) = provider.checkUpkeep(checkData);
        provider.performUpkeep(performData2);
        
        // 6. Continue until contracts expire
        skipTime(DURATION_7_DAYS);
        
        // 7. Final upkeep should end contracts
        skipToNextDay();
        (, bytes memory performData3) = provider.checkUpkeep(checkData);
        provider.performUpkeep(performData3);
        
        // 8. Contracts should be inactive and removed from automation
        assertFalse(insurance1.isActive());
        assertFalse(insurance2.isActive());
        assertEq(provider.getActiveContractsCount(), 0);
    }
    
    function test_AutomationWithMixedTokenPayments() public {
        // Create USDC contract
        vm.startPrank(OWNER);
        usdc.approve(address(provider), 1000 * 10**6);
        address usdcContract = provider.newContract(
            CLIENT1,
            DURATION_7_DAYS,
            PREMIUM_100_USD,
            PAYOUT_1000_USD,
            "Tokyo,JP",
            address(usdc)
        );
        vm.stopPrank();
        
        // Activate USDC contract
        vm.startPrank(CLIENT1);
        usdc.approve(address(provider), 100 * 10**6);
        provider.payPremium(usdcContract);
        vm.stopPrank();
        
        // Should now have 3 active contracts
        assertEq(provider.getActiveContractsCount(), 3);
        
        // Automation should handle all contracts regardless of payment token
        skipToNextDay();
        bytes memory checkData = "";
        (bool upkeepNeeded, bytes memory performData) = provider.checkUpkeep(checkData);
        
        assertTrue(upkeepNeeded);
        
        address[] memory contractBatch = abi.decode(performData, (address[]));
        assertEq(contractBatch.length, 3);
        
        // Perform upkeep for all 3 contracts
        vm.expectEmit(true, false, false, false);
        emit AutomationUpkeepPerformed(block.timestamp, 3, 0);
        
        provider.performUpkeep(performData);
    }

    // =========================================================================
    // View Function Tests
    // =========================================================================
    
    function test_GetActiveContractsCount() public {
        assertEq(provider.getActiveContractsCount(), 2);
        
        // Add one more
        vm.startPrank(OWNER);
        uint256 fundingAmount = calculatePayoutETH(PAYOUT_1000_USD);
        address newContract = provider.newContract{value: fundingAmount}(
            CLIENT1,
            DURATION_7_DAYS,
            PREMIUM_100_USD,
            PAYOUT_1000_USD,
            "Berlin,DE",
            address(0)
        );
        vm.stopPrank();
        
        vm.prank(CLIENT1);
        uint256 premiumETH = calculatePremiumETH(PREMIUM_100_USD);
        provider.payPremium{value: premiumETH}(newContract);
        
        assertEq(provider.getActiveContractsCount(), 3);
        
        // Remove one
        vm.prank(OWNER);
        provider.deactivateContract(newContract);
        
        assertEq(provider.getActiveContractsCount(), 2);
    }
    
    function test_LastUpkeepTimestamp() public {
        uint256 initialTimestamp = provider.lastUpkeepTimestamp();
        
        // Perform upkeep
        skipToNextDay();
        bytes memory checkData = "";
        (, bytes memory performData) = provider.checkUpkeep(checkData);
        provider.performUpkeep(performData);
        
        uint256 newTimestamp = provider.lastUpkeepTimestamp();
        assertGt(newTimestamp, initialTimestamp);
        assertEq(newTimestamp, block.timestamp);
    }
    
    function test_AutomationEnabledFlag() public {
        assertTrue(provider.automationEnabled());
        
        vm.prank(OWNER);
        provider.setAutomationEnabled(false);
        assertFalse(provider.automationEnabled());
    }
    
    function test_UpkeepIntervalSetting() public {
        uint256 defaultInterval = provider.upkeepInterval();
        assertEq(defaultInterval, DAY_IN_SECONDS);
        
        vm.prank(OWNER);
        provider.setUpkeepInterval(2 * DAY_IN_SECONDS);
        assertEq(provider.upkeepInterval(), 2 * DAY_IN_SECONDS);
    }
}

/**
 * @title AutomationGasOptimizationTest
 * @dev Gas optimization tests for automated weather monitoring
 */
contract AutomationGasOptimizationTest is TestHelper {
    
    AutomatedInsuranceProvider public provider;
    address[] public contracts;
    
    function setUp() public {
        setupAccounts();
        
        // Deploy insurance provider
        vm.startPrank(OWNER);
        provider = new AutomatedInsuranceProvider(
            TEST_WORLD_WEATHER_KEY,
            TEST_OPEN_WEATHER_KEY,
            TEST_WEATHERBIT_KEY
        );
        vm.stopPrank();
        
        // Create test contracts
        createMultipleContracts(5);
    }
    
    function createMultipleContracts(uint256 count) internal {
        vm.startPrank(OWNER);
        uint256 fundingAmount = calculatePayoutETH(PAYOUT_1000_USD);
        uint256 premiumETH = calculatePremiumETH(PREMIUM_100_USD);
        
        for (uint256 i = 0; i < count; i++) {
            address newContract = provider.newContract{value: fundingAmount}(
                CLIENT1,
                DURATION_7_DAYS,
                PREMIUM_100_USD,
                PAYOUT_1000_USD,
                string.concat("Location", vm.toString(i)),
                address(0)
            );
            
            contracts.push(newContract);
            
            // Activate contract
            vm.stopPrank();
            vm.prank(CLIENT1);
            provider.payPremium{value: premiumETH}(newContract);
            vm.startPrank(OWNER);
        }
        
        vm.stopPrank();
    }
    
    function test_GasUsage_SingleContractUpkeep() public {
        // Create single contract scenario
        AutomatedInsuranceProvider singleProvider = new AutomatedInsuranceProvider(
            TEST_WORLD_WEATHER_KEY,
            TEST_OPEN_WEATHER_KEY,
            TEST_WEATHERBIT_KEY
        );
        
        vm.startPrank(OWNER);
        uint256 fundingAmount = calculatePayoutETH(PAYOUT_1000_USD);
        address singleContract = singleProvider.newContract{value: fundingAmount}(
            CLIENT1,
            DURATION_7_DAYS,
            PREMIUM_100_USD,
            PAYOUT_1000_USD,
            LOCATION_LONDON,
            address(0)
        );
        vm.stopPrank();
        
        uint256 premiumETH = calculatePremiumETH(PREMIUM_100_USD);
        vm.prank(CLIENT1);
        singleProvider.payPremium{value: premiumETH}(singleContract);
        
        // Measure gas for single contract upkeep
        skipToNextDay();
        bytes memory checkData = "";
        (, bytes memory performData) = singleProvider.checkUpkeep(checkData);
        
        uint256 gasStart = gasleft();
        singleProvider.performUpkeep(performData);
        uint256 gasUsed = gasStart - gasleft();
        
        console.log("Gas used for single contract upkeep:", gasUsed);
        
        // Single contract upkeep should be under 500k gas
        assertLt(gasUsed, 500_000);
    }
    
    function test_GasUsage_BatchUpkeep() public {
        // Measure gas for batch of 5 contracts
        skipToNextDay();
        bytes memory checkData = "";
        (, bytes memory performData) = provider.checkUpkeep(checkData);
        
        uint256 gasStart = gasleft();
        provider.performUpkeep(performData);
        uint256 gasUsed = gasStart - gasleft();
        
        console.log("Gas used for 5 contract batch upkeep:", gasUsed);
        console.log("Average gas per contract:", gasUsed / 5);
        
        // Batch should be more efficient than 5x individual
        // Each additional contract should cost less than the first
        assertLt(gasUsed / 5, 300_000); // Average should be under 300k per contract
    }
    
    function test_GasUsage_ScalabilityTest() public {
        // Test with maximum batch size
        createMultipleContracts(5); // Total 10 contracts
        
        skipToNextDay();
        bytes memory checkData = "";
        (, bytes memory performData) = provider.checkUpkeep(checkData);
        
        // Should be limited to 10 contracts
        address[] memory contractBatch = abi.decode(performData, (address[]));
        assertEq(contractBatch.length, 10);
        
        uint256 gasStart = gasleft();
        provider.performUpkeep(performData);
        uint256 gasUsed = gasStart - gasleft();
        
        console.log("Gas used for maximum batch (10 contracts):", gasUsed);
        console.log("Average gas per contract in max batch:", gasUsed / 10);
        
        // Maximum batch should still be reasonable
        assertLt(gasUsed, 2_000_000); // Under 2M gas for max batch
        assertLt(gasUsed / 10, 200_000); // Under 200k average per contract
    }
    
    function test_GasEfficiency_CheckUpkeepFunction() public {
        skipToNextDay();
        
        uint256 gasStart = gasleft();
        bytes memory checkData = "";
        provider.checkUpkeep(checkData);
        uint256 gasUsed = gasStart - gasleft();
        
        console.log("Gas used for checkUpkeep function:", gasUsed);
        
        // checkUpkeep should be very efficient (it's called by Keepers frequently)
        assertLt(gasUsed, 100_000);
    }
    
    function test_GasComparison_ManualVsAutomated() public {
        // Measure manual weather update
        address[] memory contractsToUpdate = new address[](5);
        for (uint256 i = 0; i < 5; i++) {
            contractsToUpdate[i] = contracts[i];
        }
        
        uint256 gasStart1 = gasleft();
        vm.prank(OWNER);
        provider.manualWeatherUpdate(contractsToUpdate);
        uint256 manualGas = gasStart1 - gasleft();
        
        // Reset contracts for comparison
        skipToNextDay();
        
        // Measure automated upkeep
        bytes memory checkData = "";
        (, bytes memory performData) = provider.checkUpkeep(checkData);
        
        uint256 gasStart2 = gasleft();
        provider.performUpkeep(performData);
        uint256 automatedGas = gasStart2 - gasleft();
        
        console.log("Manual update gas:", manualGas);
        console.log("Automated upkeep gas:", automatedGas);
        console.log("Gas difference:", 
            manualGas > automatedGas ? manualGas - automatedGas : automatedGas - manualGas);
        
        // Automated should be comparable or more efficient
        // Allow some variance due to additional automation logic
        assertLt(automatedGas, manualGas * 120 / 100); // Within 20% of manual
    }
}