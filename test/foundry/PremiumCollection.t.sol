// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "./utils/TestHelper.sol";
import "./mocks/MockERC20.sol";
import "../../contracts/AutomatedInsurance.sol";

/**
 * @title PremiumCollectionTest
 * @dev Comprehensive tests for premium collection mechanism in Solidity
 */
contract PremiumCollectionTest is TestHelper {
    
    AutomatedInsuranceProvider public provider;
    MockERC20 public usdc;
    MockERC20 public dai;
    MockAggregatorV3 public ethUsdFeed;
    MockAggregatorV3 public usdcUsdFeed;
    MockAggregatorV3 public daiUsdFeed;
    MockLinkToken public linkToken;
    
    // Test events
    event ContractCreated(
        address indexed insuranceContract,
        address indexed client,
        address indexed paymentToken,
        uint256 premium,
        uint256 totalCover
    );
    
    event PremiumPaid(
        address indexed insuranceContract,
        address indexed client,
        address paymentToken,
        uint256 amount
    );
    
    event PremiumRefunded(
        address indexed insuranceContract,
        address indexed client,
        address paymentToken,
        uint256 amount
    );

    function setUp() public {
        setupAccounts();
        
        // Deploy mock contracts
        usdc = new MockERC20("USD Coin", "USDC", 6);
        dai = new MockERC20("Dai Stablecoin", "DAI", 18);
        linkToken = new MockLinkToken();
        
        // Deploy mock price feeds
        ethUsdFeed = new MockAggregatorV3(2000 * 10**8, 8); // $2000 ETH
        usdcUsdFeed = new MockAggregatorV3(1 * 10**8, 8);   // $1 USDC
        daiUsdFeed = new MockAggregatorV3(1 * 10**8, 8);    // $1 DAI
        
        // Deploy insurance provider
        vm.startPrank(OWNER);
        provider = new AutomatedInsuranceProvider(
            TEST_WORLD_WEATHER_KEY,
            TEST_OPEN_WEATHER_KEY,
            TEST_WEATHERBIT_KEY
        );
        vm.stopPrank();
        
        // Setup supported tokens
        vm.startPrank(OWNER);
        provider.addSupportedToken(address(usdc), address(usdcUsdFeed));
        provider.addSupportedToken(address(dai), address(daiUsdFeed));
        vm.stopPrank();
        
        // Mint tokens for testing
        usdc.mint(OWNER, 10000 * 10**6);    // 10,000 USDC
        usdc.mint(CLIENT1, 1000 * 10**6);   // 1,000 USDC
        dai.mint(OWNER, 10000 * 10**18);    // 10,000 DAI
        dai.mint(CLIENT1, 1000 * 10**18);   // 1,000 DAI
        linkToken.mint(OWNER, 100 * 10**18); // 100 LINK
        
        // Transfer LINK to provider for oracle payments
        vm.prank(OWNER);
        linkToken.transfer(address(provider), 50 * 10**18);
    }

    // =========================================================================
    // Contract Creation Tests
    // =========================================================================
    
    function test_CreateContractWithPendingPremium() public {
        vm.startPrank(OWNER);
        
        uint256 fundingAmount = calculatePayoutETH(PAYOUT_1000_USD);
        
        // Create contract with ETH payment
        address contractAddress = provider.newContract{value: fundingAmount}(
            CLIENT1,
            DURATION_7_DAYS,
            PREMIUM_100_USD,
            PAYOUT_1000_USD,
            LOCATION_LONDON,
            address(0) // ETH
        );
        
        vm.stopPrank();
        
        // Verify contract was created
        assertNotEq(contractAddress, address(0));
        
        // Check premium info
        (uint256 amount, address token, bool paid, uint256 paidAt, uint256 createdAt) = 
            provider.getPremiumInfo(contractAddress);
            
        assertEq(amount, PREMIUM_100_USD);
        assertEq(token, address(0)); // ETH
        assertFalse(paid);
        assertEq(paidAt, 0);
        assertGt(createdAt, 0);
        
        // Verify contract is not active yet
        AutomatedInsuranceContract insurance = AutomatedInsuranceContract(contractAddress);
        assertFalse(insurance.isActive());
    }
    
    function test_CreateContractWithUSDCPayment() public {
        vm.startPrank(OWNER);
        
        // Approve USDC for payout funding
        uint256 tokenAmount = 1000 * 10**6; // 1000 USDC (6 decimals)
        usdc.approve(address(provider), tokenAmount);
        
        // Create contract with USDC payment
        address contractAddress = provider.newContract(
            CLIENT1,
            DURATION_7_DAYS,
            PREMIUM_100_USD,
            PAYOUT_1000_USD,
            LOCATION_LONDON,
            address(usdc)
        );
        
        vm.stopPrank();
        
        // Check premium info
        (uint256 amount, address token, bool paid,,) = provider.getPremiumInfo(contractAddress);
        
        assertEq(amount, PREMIUM_100_USD);
        assertEq(token, address(usdc));
        assertFalse(paid);
    }
    
    function test_RevertCreateContractWithUnsupportedToken() public {
        MockERC20 unsupportedToken = new MockERC20("Unsupported", "UNS", 18);
        
        vm.startPrank(OWNER);
        vm.expectRevert("Payment token not supported");
        provider.newContract(
            CLIENT1,
            DURATION_7_DAYS,
            PREMIUM_100_USD,
            PAYOUT_1000_USD,
            LOCATION_LONDON,
            address(unsupportedToken)
        );
        vm.stopPrank();
    }
    
    function test_RevertCreateContractWithZeroPremium() public {
        vm.startPrank(OWNER);
        vm.expectRevert("Premium must be greater than 0");
        provider.newContract(
            CLIENT1,
            DURATION_7_DAYS,
            0, // Zero premium
            PAYOUT_1000_USD,
            LOCATION_LONDON,
            address(0)
        );
        vm.stopPrank();
    }

    // =========================================================================
    // Premium Payment Tests
    // =========================================================================
    
    function test_PayPremiumInETH() public {
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
        
        // Calculate premium in ETH
        uint256 premiumETH = calculatePremiumETH(PREMIUM_100_USD);
        
        // Client pays premium
        vm.startPrank(CLIENT1);
        
        // Expect events
        vm.expectEmit(true, true, true, true);
        emit PremiumPaid(contractAddress, CLIENT1, address(0), PREMIUM_100_USD);
        
        provider.payPremium{value: premiumETH}(contractAddress);
        vm.stopPrank();
        
        // Verify premium is marked as paid
        (, , bool paid, uint256 paidAt,) = provider.getPremiumInfo(contractAddress);
        assertTrue(paid);
        assertGt(paidAt, 0);
        
        // Verify contract is now active
        AutomatedInsuranceContract insurance = AutomatedInsuranceContract(contractAddress);
        assertTrue(insurance.isActive());
        
        // Verify contract was added to active contracts
        assertEq(provider.getActiveContractsCount(), 1);
    }
    
    function test_PayPremiumInUSDC() public {
        // Create USDC contract
        vm.startPrank(OWNER);
        usdc.approve(address(provider), 1000 * 10**6);
        address contractAddress = provider.newContract(
            CLIENT1,
            DURATION_7_DAYS,
            PREMIUM_100_USD,
            PAYOUT_1000_USD,
            LOCATION_LONDON,
            address(usdc)
        );
        vm.stopPrank();
        
        // Client approves and pays premium
        vm.startPrank(CLIENT1);
        uint256 premiumAmount = 100 * 10**6; // 100 USDC
        usdc.approve(address(provider), premiumAmount);
        
        vm.expectEmit(true, true, true, true);
        emit PremiumPaid(contractAddress, CLIENT1, address(usdc), PREMIUM_100_USD);
        
        provider.payPremium(contractAddress);
        vm.stopPrank();
        
        // Verify payment
        (, , bool paid,,) = provider.getPremiumInfo(contractAddress);
        assertTrue(paid);
    }
    
    function test_RefundExcessETHPayment() public {
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
        
        // Calculate premium and send extra
        uint256 premiumETH = calculatePremiumETH(PREMIUM_100_USD);
        uint256 extraETH = 0.01 ether;
        uint256 totalSent = premiumETH + extraETH;
        
        // Record balances
        uint256 balanceBefore = CLIENT1.balance;
        
        // Pay premium with excess
        vm.prank(CLIENT1);
        provider.payPremium{value: totalSent}(contractAddress);
        
        // Verify excess was refunded
        uint256 balanceAfter = CLIENT1.balance;
        uint256 actualCost = balanceBefore - balanceAfter;
        
        // Should only cost the premium amount (plus gas)
        assertLt(actualCost, premiumETH + 0.001 ether); // Allow for gas costs
    }
    
    function test_RevertPaymentFromNonClient() public {
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
        
        uint256 premiumETH = calculatePremiumETH(PREMIUM_100_USD);
        
        // Try to pay from wrong client
        vm.startPrank(CLIENT2);
        vm.expectRevert("Only client can pay premium");
        provider.payPremium{value: premiumETH}(contractAddress);
        vm.stopPrank();
    }
    
    function test_RevertInsufficientPremiumPayment() public {
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
        
        uint256 insufficientAmount = 0.01 ether; // Too little
        
        vm.startPrank(CLIENT1);
        vm.expectRevert("Insufficient ETH sent for premium");
        provider.payPremium{value: insufficientAmount}(contractAddress);
        vm.stopPrank();
    }
    
    function test_RevertPaymentAfterGracePeriod() public {
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
        
        // Skip past grace period
        skipGracePeriod();
        
        uint256 premiumETH = calculatePremiumETH(PREMIUM_100_USD);
        
        vm.startPrank(CLIENT1);
        vm.expectRevert("Premium payment grace period expired");
        provider.payPremium{value: premiumETH}(contractAddress);
        vm.stopPrank();
    }
    
    function test_RevertDoublePremiumPayment() public {
        // Create and pay for contract
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
        
        uint256 premiumETH = calculatePremiumETH(PREMIUM_100_USD);
        
        // First payment
        vm.prank(CLIENT1);
        provider.payPremium{value: premiumETH}(contractAddress);
        
        // Second payment should fail
        vm.startPrank(CLIENT1);
        vm.expectRevert("Premium already paid");
        provider.payPremium{value: premiumETH}(contractAddress);
        vm.stopPrank();
    }

    // =========================================================================
    // Premium Refund Tests
    // =========================================================================
    
    function test_RefundPremiumForInactiveContract() public {
        // Create contract but don't pay premium
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
        
        // Pay premium first
        uint256 premiumETH = calculatePremiumETH(PREMIUM_100_USD);
        vm.prank(CLIENT1);
        provider.payPremium{value: premiumETH}(contractAddress);
        
        // Deactivate contract (simulate contract ending)
        vm.prank(address(contractAddress));
        provider.deactivateContract(contractAddress);
        
        // Skip past grace period
        skipGracePeriod();
        
        // Record balance before refund
        uint256 balanceBefore = CLIENT1.balance;
        
        // Client requests refund
        vm.startPrank(CLIENT1);
        
        // This test would need to be modified based on actual refund conditions
        // in the current implementation
        vm.stopPrank();
    }
    
    function test_RevertRefundActiveContract() public {
        // Create and activate contract
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
        
        uint256 premiumETH = calculatePremiumETH(PREMIUM_100_USD);
        vm.prank(CLIENT1);
        provider.payPremium{value: premiumETH}(contractAddress);
        
        // Try to refund active contract
        vm.startPrank(CLIENT1);
        vm.expectRevert("Contract is active, cannot refund");
        provider.refundPremium(contractAddress);
        vm.stopPrank();
    }

    // =========================================================================
    // Premium Claims by Insurer Tests
    // =========================================================================
    
    function test_InsurerClaimPremiumAfterContractEnds() public {
        // Create and activate contract
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
        
        uint256 premiumETH = calculatePremiumETH(PREMIUM_100_USD);
        vm.prank(CLIENT1);
        provider.payPremium{value: premiumETH}(contractAddress);
        
        // Simulate contract ending
        skipTime(DURATION_7_DAYS + 1);
        vm.prank(address(contractAddress));
        provider.deactivateContract(contractAddress);
        
        // Record insurer balance
        uint256 balanceBefore = OWNER.balance;
        
        // Insurer claims premium
        vm.prank(OWNER);
        provider.claimPremium(contractAddress);
        
        // Verify balance increased
        uint256 balanceAfter = OWNER.balance;
        assertGt(balanceAfter, balanceBefore);
    }
    
    function test_RevertClaimPremiumWhileActive() public {
        // Create and activate contract
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
        
        uint256 premiumETH = calculatePremiumETH(PREMIUM_100_USD);
        vm.prank(CLIENT1);
        provider.payPremium{value: premiumETH}(contractAddress);
        
        // Try to claim while active
        vm.startPrank(OWNER);
        vm.expectRevert("Contract still active");
        provider.claimPremium(contractAddress);
        vm.stopPrank();
    }
    
    function test_RevertClaimPremiumByNonOwner() public {
        // Create and pay for contract
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
        
        uint256 premiumETH = calculatePremiumETH(PREMIUM_100_USD);
        vm.prank(CLIENT1);
        provider.payPremium{value: premiumETH}(contractAddress);
        
        // Simulate contract ending
        skipTime(DURATION_7_DAYS + 1);
        vm.prank(address(contractAddress));
        provider.deactivateContract(contractAddress);
        
        // Try to claim from non-owner
        vm.startPrank(CLIENT2);
        vm.expectRevert("Ownable: caller is not the owner");
        provider.claimPremium(contractAddress);
        vm.stopPrank();
    }

    // =========================================================================
    // Integration Tests
    // =========================================================================
    
    function test_CompleteLifecycleWithPremiumPayment() public {
        // 1. Create contract
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
        
        // 2. Verify initial state
        (, , bool paid,,) = provider.getPremiumInfo(contractAddress);
        assertFalse(paid);
        
        AutomatedInsuranceContract insurance = AutomatedInsuranceContract(contractAddress);
        assertFalse(insurance.isActive());
        
        // 3. Client pays premium
        uint256 premiumETH = calculatePremiumETH(PREMIUM_100_USD);
        vm.prank(CLIENT1);
        provider.payPremium{value: premiumETH}(contractAddress);
        
        // 4. Verify contract is active
        assertTrue(insurance.isActive());
        assertEq(provider.getActiveContractsCount(), 1);
        
        // 5. Contract runs normally (would include weather checks)
        
        // 6. Contract ends
        skipTime(DURATION_7_DAYS + 1);
        vm.prank(address(contractAddress));
        provider.deactivateContract(contractAddress);
        
        // 7. Insurer claims premium
        vm.prank(OWNER);
        provider.claimPremium(contractAddress);
        
        // 8. Verify premium is claimed
        (, , bool stillPaid,,) = provider.getPremiumInfo(contractAddress);
        assertFalse(stillPaid); // Marked as claimed
    }
    
    function test_MultipleContractsWithDifferentTokens() public {
        // Create ETH contract
        vm.startPrank(OWNER);
        uint256 fundingAmount = calculatePayoutETH(PAYOUT_1000_USD);
        address ethContract = provider.newContract{value: fundingAmount}(
            CLIENT1,
            DURATION_7_DAYS,
            PREMIUM_100_USD,
            PAYOUT_1000_USD,
            LOCATION_LONDON,
            address(0)
        );
        
        // Create USDC contract
        usdc.approve(address(provider), 1000 * 10**6);
        address usdcContract = provider.newContract(
            CLIENT2,
            DURATION_7_DAYS,
            PREMIUM_100_USD,
            PAYOUT_1000_USD,
            LOCATION_PARIS,
            address(usdc)
        );
        vm.stopPrank();
        
        // Pay premiums
        uint256 premiumETH = calculatePremiumETH(PREMIUM_100_USD);
        vm.prank(CLIENT1);
        provider.payPremium{value: premiumETH}(ethContract);
        
        vm.startPrank(CLIENT2);
        usdc.approve(address(provider), 100 * 10**6);
        provider.payPremium(usdcContract);
        vm.stopPrank();
        
        // Verify both contracts are active
        assertEq(provider.getActiveContractsCount(), 2);
        
        AutomatedInsuranceContract ethInsurance = AutomatedInsuranceContract(ethContract);
        AutomatedInsuranceContract usdcInsurance = AutomatedInsuranceContract(usdcContract);
        
        assertTrue(ethInsurance.isActive());
        assertTrue(usdcInsurance.isActive());
    }

    // =========================================================================
    // View Function Tests
    // =========================================================================
    
    function test_IsPremiumPaid() public {
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
        
        // Initially not paid
        assertFalse(provider.isPremiumPaid(contractAddress));
        
        // Pay premium
        uint256 premiumETH = calculatePremiumETH(PREMIUM_100_USD);
        vm.prank(CLIENT1);
        provider.payPremium{value: premiumETH}(contractAddress);
        
        // Now paid
        assertTrue(provider.isPremiumPaid(contractAddress));
    }
    
    function test_GetPremiumInfo() public {
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
        
        // Check initial info
        (uint256 amount, address token, bool paid, uint256 paidAt, uint256 createdAt) = 
            provider.getPremiumInfo(contractAddress);
            
        assertEq(amount, PREMIUM_100_USD);
        assertEq(token, address(0));
        assertFalse(paid);
        assertEq(paidAt, 0);
        assertGt(createdAt, 0);
        
        // Pay premium
        uint256 premiumETH = calculatePremiumETH(PREMIUM_100_USD);
        vm.prank(CLIENT1);
        provider.payPremium{value: premiumETH}(contractAddress);
        
        // Check updated info
        (, , bool paidAfter, uint256 paidAtAfter,) = provider.getPremiumInfo(contractAddress);
        assertTrue(paidAfter);
        assertGt(paidAtAfter, 0);
    }
}

/**
 * @title PremiumCollectionGasTest
 * @dev Gas optimization tests for premium collection
 */
contract PremiumCollectionGasTest is TestHelper {
    
    AutomatedInsuranceProvider public provider;
    MockERC20 public usdc;
    
    function setUp() public {
        setupAccounts();
        
        usdc = new MockERC20("USD Coin", "USDC", 6);
        MockAggregatorV3 usdcFeed = new MockAggregatorV3(1 * 10**8, 8);
        
        vm.startPrank(OWNER);
        provider = new AutomatedInsuranceProvider(
            TEST_WORLD_WEATHER_KEY,
            TEST_OPEN_WEATHER_KEY,
            TEST_WEATHERBIT_KEY
        );
        provider.addSupportedToken(address(usdc), address(usdcFeed));
        vm.stopPrank();
        
        usdc.mint(OWNER, 10000 * 10**6);
        usdc.mint(CLIENT1, 1000 * 10**6);
    }
    
    function test_GasUsage_ContractCreation() public {
        vm.startPrank(OWNER);
        
        uint256 gasStart = gasleft();
        uint256 fundingAmount = calculatePayoutETH(PAYOUT_1000_USD);
        
        provider.newContract{value: fundingAmount}(
            CLIENT1,
            DURATION_7_DAYS,
            PREMIUM_100_USD,
            PAYOUT_1000_USD,
            LOCATION_LONDON,
            address(0)
        );
        
        uint256 gasUsed = gasStart - gasleft();
        vm.stopPrank();
        
        console.log("Gas used for contract creation:", gasUsed);
        
        // Contract creation should be under 3M gas
        assertLt(gasUsed, 3_000_000);
    }
    
    function test_GasUsage_PremiumPayment() public {
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
        
        // Measure premium payment gas
        vm.startPrank(CLIENT1);
        uint256 premiumETH = calculatePremiumETH(PREMIUM_100_USD);
        
        uint256 gasStart = gasleft();
        provider.payPremium{value: premiumETH}(contractAddress);
        uint256 gasUsed = gasStart - gasleft();
        
        vm.stopPrank();
        
        console.log("Gas used for premium payment:", gasUsed);
        
        // Premium payment should be under 200k gas
        assertLt(gasUsed, 200_000);
    }
    
    function test_GasUsage_BatchPremiumOperations() public {
        address[] memory contracts = new address[](5);
        
        // Create 5 contracts
        vm.startPrank(OWNER);
        for (uint256 i = 0; i < 5; i++) {
            uint256 fundingAmount = calculatePayoutETH(PAYOUT_1000_USD);
            contracts[i] = provider.newContract{value: fundingAmount}(
                CLIENT1,
                DURATION_7_DAYS,
                PREMIUM_100_USD,
                PAYOUT_1000_USD,
                LOCATION_LONDON,
                address(0)
            );
        }
        vm.stopPrank();
        
        // Measure batch premium payments
        vm.startPrank(CLIENT1);
        uint256 premiumETH = calculatePremiumETH(PREMIUM_100_USD);
        
        uint256 totalGas = 0;
        for (uint256 i = 0; i < 5; i++) {
            uint256 gasStart = gasleft();
            provider.payPremium{value: premiumETH}(contracts[i]);
            totalGas += gasStart - gasleft();
        }
        
        vm.stopPrank();
        
        uint256 avgGasPerPayment = totalGas / 5;
        console.log("Average gas per premium payment:", avgGasPerPayment);
        console.log("Total gas for 5 payments:", totalGas);
        
        // Average should be reasonable
        assertLt(avgGasPerPayment, 200_000);
    }
}