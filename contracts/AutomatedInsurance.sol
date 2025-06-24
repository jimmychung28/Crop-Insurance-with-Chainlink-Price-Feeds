// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// Chainlink Automation imports (v2.1+)
import "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";
import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";
import "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

// OpenZeppelin imports
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// EAS imports
import "./eas/interfaces/IEASInsurance.sol";
import "./eas/EASInsuranceManager.sol";

/**
 * @title AutomatedInsuranceProvider
 * @dev Insurance provider with Chainlink Automation for automated weather monitoring
 */
contract AutomatedInsuranceProvider is Ownable, AutomationCompatibleInterface {
    using SafeERC20 for IERC20;
    
    address public insurer;
    AggregatorV3Interface internal ethUsdPriceFeed;
    
    // EAS integration
    EASInsuranceManager public easManager;
    bool public easEnabled = false;

    // Constants
    uint256 public constant DAY_IN_SECONDS = 86400; // Production: 86400, Testing: 60
    uint256 private constant ORACLE_PAYMENT = 0.1 * 10**18; // 0.1 LINK
    uint256 public constant PREMIUM_GRACE_PERIOD = 1 days;
    uint256 public constant MAX_CONTRACTS_PER_BATCH = 10; // Gas optimization
    
    address public constant LINK_TOKEN = 0xa36085F69e2889c224210F603D836748e7dC0088;

    // Contract storage
    mapping(address => AutomatedInsuranceContract) public contracts;
    address[] public activeContracts; // Array for batch processing
    mapping(address => uint256) public contractIndex; // For efficient removal
    
    // Premium collection tracking
    mapping(address => PremiumInfo) public premiumInfo;
    
    struct PremiumInfo {
        uint256 amount;
        address token;
        bool paid;
        uint256 paidAt;
        uint256 createdAt;
    }
    
    // Automation state
    uint256 public lastUpkeepTimestamp;
    uint256 public upkeepInterval = DAY_IN_SECONDS;
    bool public automationEnabled = true;
    
    // Supported payment tokens
    mapping(address => bool) public supportedTokens;
    mapping(address => AggregatorV3Interface) public tokenPriceFeeds;
    
    // Common stablecoin addresses
    address public USDC;
    address public DAI;
    address public USDT;

    // API Keys for weather data
    string public worldWeatherOnlineKey;
    string public openWeatherKey;
    string public weatherbitKey;

    // Events
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
    
    event AutomationUpkeepPerformed(
        uint256 timestamp,
        uint256 contractsProcessed,
        uint256 gasUsed
    );
    
    event ContractActivated(address indexed contractAddress);
    event ContractDeactivated(address indexed contractAddress);
    event TokenAdded(address indexed token, address priceFeed);
    event TokenRemoved(address indexed token);
    
    // EAS events
    event EASManagerSet(address indexed easManager);
    event EASToggled(bool enabled);
    event PolicyAttestationCreated(address indexed contract_, bytes32 attestationUID);
    event PremiumAttestationCreated(address indexed contract_, bytes32 attestationUID);

    constructor(
        string memory _worldWeatherKey,
        string memory _openWeatherKey,
        string memory _weatherbitKey
    ) {
        insurer = msg.sender;
        ethUsdPriceFeed = AggregatorV3Interface(0x9326BFA02ADD2366b30bacB125260Af641031331);
        worldWeatherOnlineKey = _worldWeatherKey;
        openWeatherKey = _openWeatherKey;
        weatherbitKey = _weatherbitKey;
        
        // ETH is always supported
        supportedTokens[address(0)] = true;
        lastUpkeepTimestamp = block.timestamp;
    }
    
    /**
     * @dev Set EAS Manager contract
     */
    function setEASManager(address _easManager) external onlyOwner {
        require(_easManager != address(0), "Invalid EAS manager address");
        easManager = EASInsuranceManager(_easManager);
        emit EASManagerSet(_easManager);
    }
    
    /**
     * @dev Toggle EAS integration on/off
     */
    function toggleEAS(bool _enabled) external onlyOwner {
        require(address(easManager) != address(0), "EAS manager not set");
        easEnabled = _enabled;
        emit EASToggled(_enabled);
    }

    /**
     * @dev Chainlink Automation checkUpkeep function
     * Determines if automated weather monitoring should be performed
     */
    function checkUpkeep(bytes calldata /* checkData */)
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        // Check if enough time has passed since last upkeep
        bool timeHasPassed = (block.timestamp - lastUpkeepTimestamp) >= upkeepInterval;
        
        // Check if there are active contracts to monitor
        bool hasActiveContracts = activeContracts.length > 0;
        
        // Check if automation is enabled
        upkeepNeeded = timeHasPassed && hasActiveContracts && automationEnabled;
        
        if (upkeepNeeded) {
            // Prepare batch data for gas-efficient processing
            uint256 batchSize = activeContracts.length > MAX_CONTRACTS_PER_BATCH 
                ? MAX_CONTRACTS_PER_BATCH 
                : activeContracts.length;
                
            address[] memory contractBatch = new address[](batchSize);
            for (uint256 i = 0; i < batchSize; i++) {
                contractBatch[i] = activeContracts[i];
            }
            
            performData = abi.encode(contractBatch);
        }
    }

    /**
     * @dev Chainlink Automation performUpkeep function
     * Performs automated weather monitoring for batch of contracts
     */
    function performUpkeep(bytes calldata performData) external override {
        uint256 gasStart = gasleft();
        
        // Decode the batch of contracts to process
        address[] memory contractBatch = abi.decode(performData, (address[]));
        
        // Verify upkeep is needed (re-validation)
        require(
            (block.timestamp - lastUpkeepTimestamp) >= upkeepInterval,
            "Upkeep not needed"
        );
        require(automationEnabled, "Automation disabled");
        
        uint256 contractsProcessed = 0;
        
        // Process each contract in the batch
        for (uint256 i = 0; i < contractBatch.length && contractsProcessed < MAX_CONTRACTS_PER_BATCH; i++) {
            address contractAddr = contractBatch[i];
            AutomatedInsuranceContract insurance = AutomatedInsuranceContract(contractAddr);
            
            // Verify contract is still active and needs update
            if (insurance.isActive() && insurance.needsWeatherUpdate()) {
                try insurance.performAutomatedWeatherCheck() {
                    contractsProcessed++;
                } catch {
                    // Log error but continue processing other contracts
                    // Contract will be checked again in next upkeep
                }
            }
        }
        
        lastUpkeepTimestamp = block.timestamp;
        uint256 gasUsed = gasStart - gasleft();
        
        emit AutomationUpkeepPerformed(block.timestamp, contractsProcessed, gasUsed);
    }

    /**
     * @dev Create a new automated insurance contract
     */
    function newContract(
        address _client,
        uint256 _duration,
        uint256 _premium,
        uint256 _payoutValue,
        string memory _cropLocation,
        address _paymentToken
    )
        public
        payable
        onlyOwner
        returns (address)
    {
        require(supportedTokens[_paymentToken], "Payment token not supported");
        require(_premium > 0, "Premium must be greater than 0");
        require(_client != address(0), "Invalid client address");
        
        // Calculate funding amount based on payment token
        uint256 fundingAmount;
        if (_paymentToken == address(0)) {
            fundingAmount = (_payoutValue * 1 ether) / uint256(getLatestPrice());
            require(msg.value >= fundingAmount, "Insufficient ETH sent for payout");
        } else {
            fundingAmount = 0;
        }
        
        AutomatedInsuranceContract insurance = new AutomatedInsuranceContract{value: fundingAmount}(
            _client,
            _duration,
            _premium,
            _payoutValue,
            _cropLocation,
            _paymentToken,
            LINK_TOKEN,
            ORACLE_PAYMENT,
            worldWeatherOnlineKey,
            openWeatherKey,
            weatherbitKey
        );

        contracts[address(insurance)] = insurance;
        
        // Store premium information
        premiumInfo[address(insurance)] = PremiumInfo({
            amount: _premium,
            token: _paymentToken,
            paid: false,
            paidAt: 0,
            createdAt: block.timestamp
        });
        
        // Handle token transfers for payouts
        if (_paymentToken != address(0)) {
            uint256 tokenAmount = getTokenAmountForUSD(_paymentToken, _payoutValue);
            IERC20(_paymentToken).safeTransferFrom(msg.sender, address(insurance), tokenAmount);
        }

        // Fund with LINK tokens for oracle requests
        LinkTokenInterface link = LinkTokenInterface(LINK_TOKEN);
        uint256 linkAmount = ((_duration / DAY_IN_SECONDS) + 2) * ORACLE_PAYMENT * 2;
        link.transfer(address(insurance), linkAmount);

        emit ContractCreated(address(insurance), _client, _paymentToken, _premium, _payoutValue);
        
        // Create EAS policy attestation if enabled
        if (easEnabled && address(easManager) != address(0)) {
            try easManager.createPolicyAttestation(
                address(insurance),
                _client,
                _premium,
                _payoutValue,
                _cropLocation,
                block.timestamp,
                _duration,
                false // Not active until premium is paid
            ) returns (bytes32 attestationUID) {
                emit PolicyAttestationCreated(address(insurance), attestationUID);
            } catch {
                // Continue execution if EAS fails
            }
        }
        
        return address(insurance);
    }

    /**
     * @dev Client pays premium and activates contract for automation
     */
    function payPremium(address _contract) external payable {
        require(contracts[_contract] != AutomatedInsuranceContract(address(0)), "Contract does not exist");
        PremiumInfo storage info = premiumInfo[_contract];
        require(!info.paid, "Premium already paid");
        require(block.timestamp <= info.createdAt + PREMIUM_GRACE_PERIOD, "Premium payment grace period expired");
        
        AutomatedInsuranceContract insurance = AutomatedInsuranceContract(_contract);
        require(insurance.client() == msg.sender, "Only client can pay premium");
        
        if (info.token == address(0)) {
            // ETH payment
            uint256 ethAmount = (info.amount * 1 ether) / uint256(getLatestPrice());
            require(msg.value >= ethAmount, "Insufficient ETH sent for premium");
            
            if (msg.value > ethAmount) {
                payable(msg.sender).transfer(msg.value - ethAmount);
            }
        } else {
            // ERC20 payment
            uint256 tokenAmount = getTokenAmountForUSD(info.token, info.amount);
            IERC20(info.token).safeTransferFrom(msg.sender, address(this), tokenAmount);
        }
        
        info.paid = true;
        info.paidAt = block.timestamp;
        
        // Activate contract and add to automation queue
        insurance.activateContract();
        _addToActiveContracts(_contract);
        
        emit PremiumPaid(_contract, msg.sender, info.token, info.amount);
        emit ContractActivated(_contract);
        
        // Create EAS premium attestation if enabled
        if (easEnabled && address(easManager) != address(0)) {
            try easManager.createPremiumAttestation(
                _contract,
                msg.sender,
                info.amount,
                info.token,
                true // Premium paid
            ) returns (bytes32 attestationUID) {
                emit PremiumAttestationCreated(_contract, attestationUID);
            } catch {
                // Continue execution if EAS fails
            }
        }
    }

    /**
     * @dev Remove contract from automation when it becomes inactive
     */
    function deactivateContract(address _contract) external {
        AutomatedInsuranceContract insurance = AutomatedInsuranceContract(_contract);
        require(
            address(insurance) == msg.sender || msg.sender == owner(),
            "Only contract or owner can deactivate"
        );
        
        _removeFromActiveContracts(_contract);
        emit ContractDeactivated(_contract);
    }

    /**
     * @dev Add contract to active contracts array for automation
     */
    function _addToActiveContracts(address _contract) internal {
        // Check if already in array
        if (contractIndex[_contract] == 0 && (activeContracts.length == 0 || activeContracts[0] != _contract)) {
            activeContracts.push(_contract);
            contractIndex[_contract] = activeContracts.length;
        }
    }

    /**
     * @dev Remove contract from active contracts array
     */
    function _removeFromActiveContracts(address _contract) internal {
        uint256 index = contractIndex[_contract];
        if (index > 0) {
            // Move last element to deleted spot
            address lastContract = activeContracts[activeContracts.length - 1];
            activeContracts[index - 1] = lastContract;
            contractIndex[lastContract] = index;
            
            // Remove last element
            activeContracts.pop();
            delete contractIndex[_contract];
        }
    }

    /**
     * @dev Get number of active contracts
     */
    function getActiveContractsCount() external view returns (uint256) {
        return activeContracts.length;
    }

    /**
     * @dev Get active contracts in range (for pagination)
     */
    function getActiveContracts(uint256 start, uint256 limit) 
        external 
        view 
        returns (address[] memory) 
    {
        require(start < activeContracts.length, "Start index out of bounds");
        
        uint256 end = start + limit;
        if (end > activeContracts.length) {
            end = activeContracts.length;
        }
        
        address[] memory result = new address[](end - start);
        for (uint256 i = start; i < end; i++) {
            result[i - start] = activeContracts[i];
        }
        
        return result;
    }

    /**
     * @dev Toggle automation on/off
     */
    function setAutomationEnabled(bool _enabled) external onlyOwner {
        automationEnabled = _enabled;
    }

    /**
     * @dev Set upkeep interval
     */
    function setUpkeepInterval(uint256 _interval) external onlyOwner {
        require(_interval >= 3600, "Minimum 1 hour interval"); // Prevent spam
        upkeepInterval = _interval;
    }

    /**
     * @dev Emergency function to manually trigger weather updates
     */
    function manualWeatherUpdate(address[] calldata _contracts) external onlyOwner {
        for (uint256 i = 0; i < _contracts.length; i++) {
            AutomatedInsuranceContract insurance = AutomatedInsuranceContract(_contracts[i]);
            if (insurance.isActive()) {
                insurance.performAutomatedWeatherCheck();
            }
        }
    }

    // Include all other functions from previous implementation
    function getLatestPrice() public view returns (int256) {
        (
            uint80 roundID,
            int256 price,
            uint256 startedAt,
            uint256 timeStamp,
            uint80 answeredInRound
        ) = ethUsdPriceFeed.latestRoundData();
        require(timeStamp > 0, "Round not complete");
        return price;
    }

    function addSupportedToken(address token, address priceFeed) external onlyOwner {
        require(priceFeed != address(0), "Invalid price feed");
        supportedTokens[token] = true;
        tokenPriceFeeds[token] = AggregatorV3Interface(priceFeed);
        
        if (token != address(0)) {
            IERC20Metadata tokenContract = IERC20Metadata(token);
            string memory symbol = tokenContract.symbol();
            
            if (keccak256(bytes(symbol)) == keccak256(bytes("USDC"))) {
                USDC = token;
            } else if (keccak256(bytes(symbol)) == keccak256(bytes("DAI"))) {
                DAI = token;
            } else if (keccak256(bytes(symbol)) == keccak256(bytes("USDT"))) {
                USDT = token;
            }
        }
        
        emit TokenAdded(token, priceFeed);
    }

    function getTokenAmountForUSD(address token, uint256 usdAmount) public view returns (uint256) {
        require(supportedTokens[token], "Token not supported");
        require(token != address(0), "Use ETH calculation for native token");
        
        AggregatorV3Interface priceFeed = tokenPriceFeeds[token];
        require(address(priceFeed) != address(0), "Price feed not set");
        
        (, int256 price, , uint256 timeStamp, ) = priceFeed.latestRoundData();
        require(timeStamp > 0, "Round not complete");
        require(price > 0, "Invalid price");
        
        uint256 tokenAmount = (usdAmount * 1e18) / uint256(price);
        
        uint8 tokenDecimals = IERC20Metadata(token).decimals();
        if (tokenDecimals < 18) {
            tokenAmount = tokenAmount / 10**(18 - tokenDecimals);
        }
        
        return tokenAmount;
    }
    
    /**
     * @dev Get EAS manager address
     */
    function getEASManager() external view returns (address) {
        return address(easManager);
    }
    
    /**
     * @dev Check if EAS is enabled
     */
    function isEASEnabled() external view returns (bool) {
        return easEnabled && address(easManager) != address(0);
    }

    receive() external payable { }
}

/**
 * @title AutomatedInsuranceContract
 * @dev Individual insurance contract with automated weather monitoring
 */
contract AutomatedInsuranceContract is ChainlinkClient, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    
    AggregatorV3Interface internal priceFeed;

    // Constants
    uint256 public constant DAY_IN_SECONDS = 86400;
    uint256 public constant DROUGHT_DAYS_THRESHOLD = 3;
    uint256 private oraclePaymentAmount;

    // Contract parameters
    address public insurer;
    address public client;
    uint256 public startDate;
    uint256 public duration;
    uint256 public premium;
    uint256 public payoutValue;
    string public cropLocation;
    address public paymentToken;

    // Weather monitoring
    uint256[2] public currentRainfallList;
    bytes32[2] public jobIds;
    address[2] public oracles;
    
    uint256 public daysWithoutRain;
    bool public contractActive;
    bool public contractPaid = false;
    uint256 public currentRainfall = 0;
    uint256 public currentRainfallDateChecked = block.timestamp;
    uint256 public requestCount = 0;
    uint256 public dataRequestsSent = 0;
    
    // Premium and automation
    bool public premiumPaid = false;
    uint256 public activatedAt = 0;
    uint256 public lastWeatherCheck = 0;

    // API Configuration
    string public worldWeatherOnlineKey;
    string public openWeatherKey;
    string public weatherbitKey;

    // Events
    event contractCreated(address _insurer, address _client, uint _duration, uint _premium, uint _totalCover);
    event contractPaidOut(uint _paidTime, uint _totalPaid, uint _finalRainfall);
    event contractEnded(uint _endTime, uint _totalReturned);
    event contractActivated(uint256 _activatedAt);
    event AutomatedWeatherCheckPerformed(uint256 timestamp, uint256 rainfall);
    event RainfallThresholdReset(uint256 rainfall);
    event dataRequestSent(bytes32 requestId);
    event dataReceived(uint _rainfall);

    modifier onlyInsurer() {
        require(insurer == msg.sender, "Only insurer can do this");
        _;
    }

    modifier onContractActive() {
        require(contractActive == true, "Contract ended");
        require(premiumPaid == true, "Premium not paid");
        _;
    }

    constructor(
        address _client,
        uint256 _duration,
        uint256 _premium,
        uint256 _payoutValue,
        string memory _cropLocation,
        address _paymentToken,
        address _link,
        uint256 _oraclePaymentAmount,
        string memory _worldWeatherKey,
        string memory _openWeatherKey,
        string memory _weatherbitKey
    ) {
        priceFeed = AggregatorV3Interface(0x9326BFA02ADD2366b30bacB125260Af641031331);
        setChainlinkToken(_link);
        oraclePaymentAmount = _oraclePaymentAmount;

        if (_paymentToken == address(0)) {
            require(msg.value >= _payoutValue / uint256(getLatestPrice()), "Not enough funds sent to contract");
        }

        insurer = msg.sender;
        client = _client;
        startDate = block.timestamp;
        duration = _duration;
        premium = _premium;
        payoutValue = _payoutValue;
        paymentToken = _paymentToken;
        daysWithoutRain = 0;
        contractActive = false;
        cropLocation = _cropLocation;

        // API configuration
        worldWeatherOnlineKey = _worldWeatherKey;
        openWeatherKey = _openWeatherKey;
        weatherbitKey = _weatherbitKey;

        // Oracle configuration
        oracles[0] = 0x05c8fadf1798437c143683e665800d58a42b6e19;
        oracles[1] = 0x05c8fadf1798437c143683e665800d58a42b6e19;
        jobIds[0] = "a17e8fbf4cbf46eeb79e04b3eb864a4e";
        jobIds[1] = "a17e8fbf4cbf46eeb79e04b3eb864a4e";

        emit contractCreated(insurer, client, duration, premium, payoutValue);
    }

    /**
     * @dev Activate contract after premium payment
     */
    function activateContract() external onlyInsurer {
        require(!contractActive, "Contract already active");
        require(!premiumPaid, "Premium already marked as paid");
        
        premiumPaid = true;
        contractActive = true;
        activatedAt = block.timestamp;
        startDate = block.timestamp;
        lastWeatherCheck = block.timestamp;
        
        emit contractActivated(activatedAt);
    }

    /**
     * @dev Check if contract needs weather update (for automation)
     */
    function needsWeatherUpdate() external view returns (bool) {
        if (!contractActive || !premiumPaid) return false;
        if (contractPaid) return false;
        if (activatedAt + duration < block.timestamp) return false;
        
        // Check if enough time has passed since last update
        return (block.timestamp - lastWeatherCheck) >= DAY_IN_SECONDS;
    }

    /**
     * @dev Automated weather check called by Chainlink Automation
     */
    function performAutomatedWeatherCheck() external onContractActive {
        require(msg.sender == insurer, "Only insurer/automation can trigger");
        require(
            (block.timestamp - lastWeatherCheck) >= DAY_IN_SECONDS,
            "Too soon for weather check"
        );

        // Check if contract should end first
        if (activatedAt + duration < block.timestamp) {
            _endContract();
            return;
        }

        lastWeatherCheck = block.timestamp;
        dataRequestsSent = 0;

        // Request weather data from multiple sources
        _requestWeatherData();
        
        emit AutomatedWeatherCheckPerformed(block.timestamp, currentRainfall);
        
        // Create EAS weather attestation if EAS is enabled
        _createWeatherAttestation(currentRainfall);
    }

    /**
     * @dev Request weather data from multiple oracle sources
     */
    function _requestWeatherData() internal {
        // World Weather Online request
        string memory url1 = string(abi.encodePacked(
            "http://api.worldweatheronline.com/premium/v1/weather.ashx?key=",
            worldWeatherOnlineKey,
            "&q=",
            cropLocation,
            "&format=json&num_of_days=1"
        ));
        _checkRainfall(oracles[0], jobIds[0], url1, "data.current_condition.0.precipMM");

        // WeatherBit request
        string memory url2 = string(abi.encodePacked(
            "https://api.weatherbit.io/v2.0/current?city=",
            cropLocation,
            "&key=",
            weatherbitKey
        ));
        _checkRainfall(oracles[1], jobIds[1], url2, "data.0.precip");
    }

    /**
     * @dev Internal function to make oracle requests
     */
    function _checkRainfall(
        address _oracle,
        bytes32 _jobId,
        string memory _url,
        string memory _path
    ) internal returns (bytes32 requestId) {
        Chainlink.Request memory req = buildChainlinkRequest(
            _jobId,
            address(this),
            this.checkRainfallCallBack.selector
        );

        req.add("get", _url);
        req.add("path", _path);
        req.addInt("times", 100);

        requestId = sendChainlinkRequestTo(_oracle, req, oraclePaymentAmount);
        emit dataRequestSent(requestId);
    }

    /**
     * @dev Oracle callback function
     */
    function checkRainfallCallBack(bytes32 _requestId, uint256 _rainfall) 
        public 
        recordChainlinkFulfillment(_requestId) 
        onContractActive 
    {
        currentRainfallList[dataRequestsSent] = _rainfall;
        requestCount += 1;
        dataRequestsSent += 1;

        emit dataReceived(_rainfall);

        // If we have received both data points, aggregate and evaluate
        if (dataRequestsSent >= 2) {
            currentRainfall = (currentRainfallList[0] + currentRainfallList[1]) / 2;

            if (currentRainfall == 0) {
                daysWithoutRain += 1;
            } else {
                daysWithoutRain = 0;
                emit RainfallThresholdReset(currentRainfall);
            }

            if (daysWithoutRain >= DROUGHT_DAYS_THRESHOLD) {
                _payOutContract();
            }
        }
    }
    
    /**
     * @dev Create weather attestation through EAS
     */
    function _createWeatherAttestation(uint256 rainfall) internal {
        AutomatedInsuranceProvider provider = AutomatedInsuranceProvider(insurer);
        
        if (provider.easEnabled() && address(provider.easManager()) != address(0)) {
            try provider.easManager().createWeatherAttestation(
                cropLocation,
                rainfall,
                "Multi-source Weather API",
                bytes32(requestCount), // Use request count as oracle request ID
                true // Verified through multiple sources
            ) returns (bytes32 attestationUID) {
                emit WeatherAttestationCreated(attestationUID, rainfall);
            } catch {
                // Continue execution if EAS fails
            }
        }
    }

    /**
     * @dev Execute payout when drought conditions are met
     */
    function _payOutContract() internal onContractActive nonReentrant {
        contractPaid = true;
        contractActive = false;
        
        // Notify provider to remove from automation
        AutomatedInsuranceProvider(insurer).deactivateContract(address(this));
        
        if (paymentToken == address(0)) {
            payable(client).transfer(address(this).balance);
        } else {
            uint256 tokenBalance = IERC20(paymentToken).balanceOf(address(this));
            IERC20(paymentToken).safeTransfer(client, tokenBalance);
        }

        // Return remaining LINK
        LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
        require(link.transfer(insurer, link.balanceOf(address(this))), "Unable to transfer remaining LINK");
        
        emit contractPaidOut(block.timestamp, payoutValue, currentRainfall);
        
        // Create EAS claim attestation
        _createClaimAttestation(payoutValue, 3); // Status 3 = paid
    }

    /**
     * @dev End contract when duration expires
     */
    function _endContract() internal {
        contractActive = false;
        
        // Notify provider to remove from automation
        AutomatedInsuranceProvider(insurer).deactivateContract(address(this));
        
        // Return funds based on request count compliance
        if (requestCount >= (duration / DAY_IN_SECONDS - 1)) {
            // Return payout funds to insurer
            if (paymentToken == address(0)) {
                payable(insurer).transfer(address(this).balance);
            } else {
                uint256 tokenBalance = IERC20(paymentToken).balanceOf(address(this));
                IERC20(paymentToken).safeTransfer(insurer, tokenBalance);
            }
        } else {
            // Partial refund to client for insufficient monitoring
            uint256 clientRefund = premium / uint256(getLatestPrice());
            payable(client).transfer(clientRefund);
            
            if (paymentToken == address(0)) {
                payable(insurer).transfer(address(this).balance);
            } else {
                uint256 tokenBalance = IERC20(paymentToken).balanceOf(address(this));
                IERC20(paymentToken).safeTransfer(insurer, tokenBalance);
            }
        }

        // Return remaining LINK
        LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
        require(link.transfer(insurer, link.balanceOf(address(this))), "Unable to transfer remaining LINK");

        emit contractEnded(block.timestamp, address(this).balance);
    }

    // View functions
    function isActive() external view returns (bool) {
        return contractActive && premiumPaid;
    }

    function getLatestPrice() public view returns (int256) {
        (
            uint80 roundID,
            int256 price,
            uint256 startedAt,
            uint256 timeStamp,
            uint80 answeredInRound
        ) = priceFeed.latestRoundData();
        require(timeStamp > 0, "Round not complete");
        return price;
    }

    function getContractBalance() external view returns (uint256) {
        if (paymentToken == address(0)) {
            return address(this).balance;
        } else {
            return IERC20(paymentToken).balanceOf(address(this));
        }
    }

    // Additional getter functions for compatibility
    function getLocation() external view returns (string memory) { return cropLocation; }
    function getPayoutValue() external view returns (uint256) { return payoutValue; }
    function getPremium() external view returns (uint256) { return premium; }
    function getContractStatus() external view returns (bool) { return contractActive; }
    function getCurrentRainfall() external view returns (uint256) { return currentRainfall; }
    function getRequestCount() external view returns (uint256) { return requestCount; }
    function getDaysWithoutRain() external view returns (uint256) { return daysWithoutRain; }
    function getChainlinkToken() public view returns (address) { return chainlinkTokenAddress(); }
    
    /**
     * @dev Create claim attestation through EAS
     */
    function _createClaimAttestation(uint256 claimAmount, uint8 status) internal {
        AutomatedInsuranceProvider provider = AutomatedInsuranceProvider(insurer);
        
        if (provider.easEnabled() && address(provider.easManager()) != address(0)) {
            string memory evidence = string(abi.encodePacked(
                "Drought conditions met: ",
                "Days without rain: ", daysWithoutRain,
                ", Final rainfall: ", currentRainfall
            ));
            
            try provider.easManager().createClaimAttestation(
                address(this),
                claimAmount,
                status,
                evidence,
                true // Drought confirmed
            ) returns (bytes32 attestationUID) {
                emit ClaimAttestationCreated(attestationUID, claimAmount);
            } catch {
                // Continue execution if EAS fails
            }
        }
    }

    receive() external payable { }
}