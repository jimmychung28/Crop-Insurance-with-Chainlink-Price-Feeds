// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";

/**
 * @title TestHelper
 * @dev Base contract with common test utilities and helpers
 */
contract TestHelper is Test {
    
    // Common test constants
    uint256 public constant DAY_IN_SECONDS = 86400;
    uint256 public constant DROUGHT_DAYS_THRESHOLD = 3;
    uint256 public constant PREMIUM_GRACE_PERIOD = 1 days;
    uint256 public constant ORACLE_PAYMENT = 0.1 * 10**18; // 0.1 LINK
    
    // Test addresses
    address public constant OWNER = address(0x1);
    address public constant CLIENT1 = address(0x2);
    address public constant CLIENT2 = address(0x3);
    address public constant CLIENT3 = address(0x4);
    address public constant INSURANCE_PROVIDER = address(0x5);
    
    // Chainlink addresses (Sepolia testnet)
    address public constant LINK_TOKEN = 0x779877A7B0D9E8603169DdbD7836e478b4624789;
    address public constant ETH_USD_PRICE_FEED = 0x694AA1769357215DE4FAC081bf1f309aDC325306;
    address public constant USDC_USD_PRICE_FEED = 0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E;
    address public constant DAI_USD_PRICE_FEED = 0x14866185B1962B63C3Ea9E03Bc1da838bab34C19;
    
    // Test parameters
    uint256 public constant DURATION_7_DAYS = 7 * DAY_IN_SECONDS;
    uint256 public constant PREMIUM_100_USD = 100 * 10**8; // 100 USD with 8 decimals
    uint256 public constant PAYOUT_1000_USD = 1000 * 10**8; // 1000 USD with 8 decimals
    string public constant LOCATION_LONDON = "London,UK";
    string public constant LOCATION_PARIS = "Paris,FR";
    
    // API keys for testing
    string public constant TEST_WORLD_WEATHER_KEY = "test_world_weather_key";
    string public constant TEST_OPEN_WEATHER_KEY = "test_open_weather_key";
    string public constant TEST_WEATHERBIT_KEY = "test_weatherbit_key";
    
    /**
     * @dev Set up common test accounts with ETH balances
     */
    function setupAccounts() internal {
        vm.deal(OWNER, 100 ether);
        vm.deal(CLIENT1, 50 ether);
        vm.deal(CLIENT2, 50 ether);
        vm.deal(CLIENT3, 50 ether);
        vm.deal(INSURANCE_PROVIDER, 200 ether);
    }
    
    /**
     * @dev Calculate premium amount in ETH based on USD amount
     * Assumes ETH price of $2000 for testing
     */
    function calculatePremiumETH(uint256 premiumUSD) internal pure returns (uint256) {
        // premiumUSD has 8 decimals, ETH price assumed at $2000 with 8 decimals
        uint256 ethPriceUSD = 2000 * 10**8;
        return (premiumUSD * 1 ether) / ethPriceUSD;
    }
    
    /**
     * @dev Calculate payout amount in ETH based on USD amount
     */
    function calculatePayoutETH(uint256 payoutUSD) internal pure returns (uint256) {
        uint256 ethPriceUSD = 2000 * 10**8;
        return (payoutUSD * 1 ether) / ethPriceUSD;
    }
    
    /**
     * @dev Skip time forward by specified duration
     */
    function skipTime(uint256 duration) internal {
        vm.warp(block.timestamp + duration);
    }
    
    /**
     * @dev Skip to next day for weather checks
     */
    function skipToNextDay() internal {
        skipTime(DAY_IN_SECONDS + 1);
    }
    
    /**
     * @dev Advance to after grace period
     */
    function skipGracePeriod() internal {
        skipTime(PREMIUM_GRACE_PERIOD + 1);
    }
    
    /**
     * @dev Create standard contract parameters for testing
     */
    function getStandardContractParams() internal pure returns (
        address client,
        uint256 duration,
        uint256 premium,
        uint256 payout,
        string memory location,
        address paymentToken
    ) {
        return (
            CLIENT1,
            DURATION_7_DAYS,
            PREMIUM_100_USD,
            PAYOUT_1000_USD,
            LOCATION_LONDON,
            address(0) // ETH
        );
    }
    
    /**
     * @dev Expect specific revert with message
     */
    function expectRevertWithMessage(string memory message) internal {
        vm.expectRevert(abi.encodeWithSignature("Error(string)", message));
    }
    
    /**
     * @dev Mock Chainlink price feed response
     */
    function mockPriceFeed(address priceFeed, int256 price) internal {
        // Mock the latestRoundData function to return test price
        vm.mockCall(
            priceFeed,
            abi.encodeWithSignature("latestRoundData()"),
            abi.encode(
                uint80(1), // roundId
                price,     // price
                uint256(block.timestamp - 100), // startedAt
                uint256(block.timestamp), // updatedAt
                uint80(1)  // answeredInRound
            )
        );
    }
    
    /**
     * @dev Mock oracle response for weather data
     */
    function mockOracleResponse(address oracle, bytes32 requestId, uint256 rainfall) internal {
        // This would be used to simulate oracle responses in tests
        vm.mockCall(
            oracle,
            abi.encodeWithSignature("fulfillOracleRequest(bytes32,uint256)", requestId, rainfall),
            abi.encode(true)
        );
    }
    
    /**
     * @dev Get balance snapshot for gas testing
     */
    function getGasSnapshot() internal view returns (uint256) {
        return gasleft();
    }
    
    /**
     * @dev Calculate gas used between snapshots
     */
    function getGasUsed(uint256 snapshot) internal view returns (uint256) {
        return snapshot - gasleft();
    }
    
    /**
     * @dev Assert gas usage is within expected range
     */
    function assertGasUsage(uint256 actualGas, uint256 expectedGas, uint256 tolerance) internal {
        uint256 minGas = expectedGas * (100 - tolerance) / 100;
        uint256 maxGas = expectedGas * (100 + tolerance) / 100;
        
        assertGe(actualGas, minGas, "Gas usage too low");
        assertLe(actualGas, maxGas, "Gas usage too high");
    }
    
    /**
     * @dev Create array of addresses for batch testing
     */
    function createAddressArray(address addr1) internal pure returns (address[] memory) {
        address[] memory array = new address[](1);
        array[0] = addr1;
        return array;
    }
    
    function createAddressArray(address addr1, address addr2) internal pure returns (address[] memory) {
        address[] memory array = new address[](2);
        array[0] = addr1;
        array[1] = addr2;
        return array;
    }
    
    function createAddressArray(
        address addr1, 
        address addr2, 
        address addr3
    ) internal pure returns (address[] memory) {
        address[] memory array = new address[](3);
        array[0] = addr1;
        array[1] = addr2;
        array[2] = addr3;
        return array;
    }
    
    /**
     * @dev Format address for logging
     */
    function formatAddress(address addr) internal pure returns (string memory) {
        return vm.toString(addr);
    }
    
    /**
     * @dev Log contract creation details
     */
    function logContractCreation(
        address contractAddress,
        address client,
        uint256 premium,
        uint256 payout,
        string memory location
    ) internal {
        console.log("Contract Created:");
        console.log("  Address:", formatAddress(contractAddress));
        console.log("  Client:", formatAddress(client));
        console.log("  Premium:", premium / 10**8, "USD");
        console.log("  Payout:", payout / 10**8, "USD");
        console.log("  Location:", location);
    }
    
    /**
     * @dev Log premium payment details
     */
    function logPremiumPayment(
        address contractAddress,
        address client,
        uint256 amount,
        address token
    ) internal {
        console.log("Premium Paid:");
        console.log("  Contract:", formatAddress(contractAddress));
        console.log("  Client:", formatAddress(client));
        console.log("  Amount:", amount);
        console.log("  Token:", formatAddress(token));
    }
}

/**
 * @title Events
 * @dev Interface for testing events from contracts
 */
interface Events {
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
    
    event AutomationUpkeepPerformed(
        uint256 timestamp,
        uint256 contractsProcessed,
        uint256 gasUsed
    );
    
    event ContractActivated(address indexed contractAddress);
    event ContractDeactivated(address indexed contractAddress);
    
    event contractPaidOut(uint _paidTime, uint _totalPaid, uint _finalRainfall);
    event contractEnded(uint _endTime, uint _totalReturned);
    event contractActivated(uint256 _activatedAt);
    event AutomatedWeatherCheckPerformed(uint256 timestamp, uint256 rainfall);
    event RainfallThresholdReset(uint256 rainfall);
    event dataRequestSent(bytes32 requestId);
    event dataReceived(uint _rainfall);
}