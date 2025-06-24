// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// Modern Chainlink and OpenZeppelin imports
import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";
import "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract InsuranceProvider is Ownable {
    using SafeERC20 for IERC20;
    
    // Built-in overflow protection in Solidity 0.8+, no SafeMath needed
    address public insurer;
    AggregatorV3Interface internal ethUsdPriceFeed;

    // How many seconds in a day. 60 for testing, 86400 for Production
    uint256 public constant DAY_IN_SECONDS = 60;
    uint256 private constant ORACLE_PAYMENT = 0.1 * 10**18; // 0.1 LINK
    uint256 public constant PREMIUM_GRACE_PERIOD = 1 days; // Grace period for premium payment
    
    // Address of LINK token on Kovan
    address public constant LINK_KOVAN = 0xa36085F69e2889c224210F603D836748e7dC0088;

    // Here is where all the insurance contracts are stored.
    mapping(address => InsuranceContract) public contracts;
    
    // Premium collection tracking
    mapping(address => PremiumInfo) public premiumInfo;
    
    struct PremiumInfo {
        uint256 amount;
        address token;
        bool paid;
        uint256 paidAt;
        uint256 createdAt;
    }
    
    // Supported payment tokens
    mapping(address => bool) public supportedTokens;
    mapping(address => AggregatorV3Interface) public tokenPriceFeeds;
    
    // Common stablecoin addresses (to be set for each network)
    address public USDC;
    address public DAI;
    address public USDT;

    // API Keys for weather data
    string public worldWeatherOnlineKey;
    string public openWeatherKey;
    string public weatherbitKey;

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
    }

    /**
     * @dev Event to log when a contract is created
     */
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
    
    event TokenAdded(address indexed token, address priceFeed);
    event TokenRemoved(address indexed token);

    /**
     * @dev Create a new contract for client, requires premium payment within grace period
     * @param _client Address of the client
     * @param _duration Contract duration in seconds
     * @param _premium Premium amount in USD
     * @param _payoutValue Payout value in USD
     * @param _cropLocation Location of the crop for weather data
     * @param _paymentToken Token address for premium payment (address(0) for ETH)
     * @return Address of the created insurance contract
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
            // ETH payment - send ETH to contract
            fundingAmount = (_payoutValue * 1 ether) / uint256(getLatestPrice());
            require(msg.value >= fundingAmount, "Insufficient ETH sent for payout");
        } else {
            // ERC20 payment - no ETH needed for contract creation
            fundingAmount = 0;
        }
        
        InsuranceContract i = new InsuranceContract{value: fundingAmount}(
            _client,
            _duration,
            _premium,
            _payoutValue,
            _cropLocation,
            _paymentToken,
            LINK_KOVAN,
            ORACLE_PAYMENT,
            worldWeatherOnlineKey,
            openWeatherKey,
            weatherbitKey
        );

        contracts[address(i)] = i;
        
        // Store premium information
        premiumInfo[address(i)] = PremiumInfo({
            amount: _premium,
            token: _paymentToken,
            paid: false,
            paidAt: 0,
            createdAt: block.timestamp
        });
        
        // Handle token transfers based on payment type
        if (_paymentToken != address(0)) {
            // Transfer ERC20 tokens from insurer to the new contract
            uint256 tokenAmount = getTokenAmountForUSD(_paymentToken, _payoutValue);
            IERC20(_paymentToken).safeTransferFrom(msg.sender, address(i), tokenAmount);
        }

        // Emit an event to say the contract has been created and funded
        emit ContractCreated(address(i), _client, _paymentToken, _premium, _payoutValue);

        // Now that contract has been created, we need to fund it with enough LINK tokens
        // to fulfil 1 Oracle request per day, with a small buffer added
        LinkTokenInterface link = LinkTokenInterface(i.getChainlinkToken());
        uint256 linkAmount = ((_duration / DAY_IN_SECONDS) + 2) * ORACLE_PAYMENT * 2;
        link.transfer(address(i), linkAmount);

        return address(i);
    }

    /**
     * @dev Client pays premium for their insurance contract
     * @param _contract Address of the insurance contract
     */
    function payPremium(address _contract) external payable {
        require(contracts[_contract] != InsuranceContract(address(0)), "Contract does not exist");
        PremiumInfo storage info = premiumInfo[_contract];
        require(!info.paid, "Premium already paid");
        require(block.timestamp <= info.createdAt + PREMIUM_GRACE_PERIOD, "Premium payment grace period expired");
        
        InsuranceContract insurance = InsuranceContract(_contract);
        require(insurance.client() == msg.sender, "Only client can pay premium");
        
        if (info.token == address(0)) {
            // ETH payment
            uint256 ethAmount = (info.amount * 1 ether) / uint256(getLatestPrice());
            require(msg.value >= ethAmount, "Insufficient ETH sent for premium");
            
            // Refund excess ETH if any
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
        
        // Activate the insurance contract
        insurance.activateContract();
        
        emit PremiumPaid(_contract, msg.sender, info.token, info.amount);
    }

    /**
     * @dev Refund premium if contract was never activated
     * @param _contract Address of the insurance contract
     */
    function refundPremium(address _contract) external nonReentrant {
        require(contracts[_contract] != InsuranceContract(address(0)), "Contract does not exist");
        PremiumInfo storage info = premiumInfo[_contract];
        require(info.paid, "Premium not paid");
        require(block.timestamp > info.createdAt + PREMIUM_GRACE_PERIOD, "Grace period not expired");
        
        InsuranceContract insurance = InsuranceContract(_contract);
        require(!insurance.isActive(), "Contract is active, cannot refund");
        require(insurance.client() == msg.sender || msg.sender == owner(), "Unauthorized");
        
        uint256 refundAmount;
        if (info.token == address(0)) {
            // ETH refund
            refundAmount = (info.amount * 1 ether) / uint256(getLatestPrice());
            payable(insurance.client()).transfer(refundAmount);
        } else {
            // ERC20 refund
            refundAmount = getTokenAmountForUSD(info.token, info.amount);
            IERC20(info.token).safeTransfer(insurance.client(), refundAmount);
        }
        
        info.paid = false;
        emit PremiumRefunded(_contract, insurance.client(), info.token, info.amount);
    }

    /**
     * @dev Insurer claims collected premiums for expired/completed contracts
     * @param _contract Address of the insurance contract
     */
    function claimPremium(address _contract) external onlyOwner nonReentrant {
        require(contracts[_contract] != InsuranceContract(address(0)), "Contract does not exist");
        PremiumInfo storage info = premiumInfo[_contract];
        require(info.paid, "Premium not paid");
        
        InsuranceContract insurance = InsuranceContract(_contract);
        require(!insurance.isActive() || insurance.contractEnded(), "Contract still active");
        
        uint256 claimAmount;
        if (info.token == address(0)) {
            // ETH claim
            claimAmount = (info.amount * 1 ether) / uint256(getLatestPrice());
            payable(insurer).transfer(claimAmount);
        } else {
            // ERC20 claim
            claimAmount = getTokenAmountForUSD(info.token, info.amount);
            IERC20(info.token).safeTransfer(insurer, claimAmount);
        }
        
        // Mark as claimed by setting paid to false
        info.paid = false;
    }

    /**
     * @dev Check if premium is paid for a contract
     * @param _contract Address of the insurance contract
     * @return True if premium is paid
     */
    function isPremiumPaid(address _contract) external view returns (bool) {
        return premiumInfo[_contract].paid;
    }

    /**
     * @dev Get premium information for a contract
     * @param _contract Address of the insurance contract
     * @return Premium amount, token address, paid status, paid timestamp, created timestamp
     */
    function getPremiumInfo(address _contract) external view returns (
        uint256 amount,
        address token,
        bool paid,
        uint256 paidAt,
        uint256 createdAt
    ) {
        PremiumInfo memory info = premiumInfo[_contract];
        return (info.amount, info.token, info.paid, info.paidAt, info.createdAt);
    }

    /**
     * @dev Returns the contract for a given address
     * @param _contract Address of the insurance contract
     * @return The insurance contract instance
     */
    function getContract(address _contract) external view returns (InsuranceContract) {
        return contracts[_contract];
    }

    /**
     * @dev Updates the contract for a given address
     * @param _contract Address of the insurance contract to update
     */
    function updateContract(address _contract) external {
        InsuranceContract i = InsuranceContract(_contract);
        i.updateContract();
    }

    /**
     * @dev Gets the current rainfall for a given contract address
     * @param _contract Address of the insurance contract
     * @return Current rainfall amount
     */
    function getContractRainfall(address _contract) external view returns (uint256) {
        InsuranceContract i = InsuranceContract(_contract);
        return i.getCurrentRainfall();
    }

    /**
     * @dev Gets the request count for a given contract address
     * @param _contract Address of the insurance contract
     * @return Number of oracle requests made
     */
    function getContractRequestCount(address _contract) external view returns (uint256) {
        InsuranceContract i = InsuranceContract(_contract);
        return i.getRequestCount();
    }

    /**
     * @dev Get the insurer address for this insurance provider
     * @return Address of the insurer
     */
    function getInsurer() external view returns (address) {
        return insurer;
    }

    /**
     * @dev Get the status of a given Contract
     * @param _address Address of the insurance contract
     * @return True if contract is active, false otherwise
     */
    function getContractStatus(address _address) external view returns (bool) {
        InsuranceContract i = InsuranceContract(_address);
        return i.getContractStatus();
    }

    /**
     * @dev Return how much ether is in this master contract
     * @return Contract balance in wei
     */
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /**
     * @dev Function to end provider contract, in case of bugs or needing to update logic etc,
     * funds are returned to insurance provider, including any remaining LINK tokens
     */
    function endContractProvider() external payable onlyOwner() {
        LinkTokenInterface link = LinkTokenInterface(LINK_KOVAN);
        require(
            link.transfer(msg.sender, link.balanceOf(address(this))),
            "Unable to transfer"
        );
        selfdestruct(payable(insurer));
    }

    /**
     * @dev Returns the latest ETH/USD price from Chainlink oracle
     * @return Latest price with 8 decimal places
     */
    function getLatestPrice() public view returns (int256) {
        (
            uint80 roundID,
            int256 price,
            uint256 startedAt,
            uint256 timeStamp,
            uint80 answeredInRound
        ) = ethUsdPriceFeed.latestRoundData();
        // If the round is not complete yet, timestamp is 0
        require(timeStamp > 0, "Round not complete");
        return price;
    }

    /**
     * @dev Add a new supported payment token
     * @param token Address of the ERC20 token (address(0) for ETH)
     * @param priceFeed Chainlink price feed for token/USD conversion
     */
    function addSupportedToken(address token, address priceFeed) external onlyOwner {
        require(priceFeed != address(0), "Invalid price feed");
        supportedTokens[token] = true;
        tokenPriceFeeds[token] = AggregatorV3Interface(priceFeed);
        
        // Set common token addresses for easy reference
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
    
    /**
     * @dev Remove a supported payment token
     * @param token Address of the token to remove
     */
    function removeSupportedToken(address token) external onlyOwner {
        require(token != address(0), "Cannot remove ETH");
        supportedTokens[token] = false;
        delete tokenPriceFeeds[token];
        
        if (token == USDC) USDC = address(0);
        if (token == DAI) DAI = address(0);
        if (token == USDT) USDT = address(0);
        
        emit TokenRemoved(token);
    }
    
    /**
     * @dev Get the token amount needed for a specific USD value
     * @param token Token address
     * @param usdAmount USD amount with 8 decimals
     * @return Token amount needed
     */
    function getTokenAmountForUSD(address token, uint256 usdAmount) public view returns (uint256) {
        require(supportedTokens[token], "Token not supported");
        require(token != address(0), "Use ETH calculation for native token");
        
        AggregatorV3Interface priceFeed = tokenPriceFeeds[token];
        require(address(priceFeed) != address(0), "Price feed not set");
        
        (, int256 price, , uint256 timeStamp, ) = priceFeed.latestRoundData();
        require(timeStamp > 0, "Round not complete");
        require(price > 0, "Invalid price");
        
        // Calculate token amount needed
        // USD amount has 8 decimals, price has 8 decimals
        uint256 tokenAmount = (usdAmount * 1e18) / uint256(price);
        
        // Adjust for token decimals
        uint8 tokenDecimals = IERC20Metadata(token).decimals();
        if (tokenDecimals < 18) {
            tokenAmount = tokenAmount / 10**(18 - tokenDecimals);
        }
        
        return tokenAmount;
    }
    
    /**
     * @dev Get the USD value of a token amount
     * @param token Token address (address(0) for ETH)
     * @param amount Amount of tokens
     * @return USD value with 8 decimals
     */
    function getTokenValueInUSD(address token, uint256 amount) public view returns (uint256) {
        require(supportedTokens[token], "Token not supported");
        
        if (token == address(0)) {
            // ETH price calculation
            int256 ethPrice = getLatestPrice();
            return (amount * uint256(ethPrice)) / 1e18;
        } else {
            // ERC20 token price calculation
            AggregatorV3Interface priceFeed = tokenPriceFeeds[token];
            require(address(priceFeed) != address(0), "Price feed not set");
            
            (, int256 price, , uint256 timeStamp, ) = priceFeed.latestRoundData();
            require(timeStamp > 0, "Round not complete");
            
            // Adjust for token decimals (assuming most stablecoins use 6 decimals)
            uint8 tokenDecimals = IERC20Metadata(token).decimals();
            if (tokenDecimals < 18) {
                amount = amount * 10**(18 - tokenDecimals);
            }
            
            return (amount * uint256(price)) / 1e18;
        }
    }

    /**
     * @dev Fallback function to receive ether
     */
    receive() external payable { }
}

contract InsuranceContract is ChainlinkClient, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    
    // Built-in overflow protection in Solidity 0.8+, no SafeMath needed
    AggregatorV3Interface internal priceFeed;

    // How many seconds in a day. 60 for testing, 86400 for Production
    uint256 public constant DAY_IN_SECONDS = 60;
    // Number of consecutive days without rainfall to be defined as a drought
    uint256 public constant DROUGHT_DAYS_THRESHOLD = 3;
    uint256 private oraclePaymentAmount;

    address public insurer;
    address public client;
    uint256 public startDate;
    uint256 public duration;
    uint256 public premium;
    uint256 public payoutValue;
    string public cropLocation;
    address public paymentToken; // Token used for premium payment

    uint256[2] public currentRainfallList;
    bytes32[2] public jobIds;
    address[2] public oracles;

    // API Configuration - keys set during deployment
    string public worldWeatherOnlineUrl;
    string public worldWeatherOnlineKey;
    string public constant WORLD_WEATHER_ONLINE_PATH = "data.current_condition.0.precipMM";

    string public openWeatherUrl;
    string public openWeatherKey;
    string public constant OPEN_WEATHER_PATH = "rain.1h";

    string public weatherbitUrl;
    string public weatherbitKey;
    string public constant WEATHERBIT_PATH = "data.0.precip";

    uint256 public daysWithoutRain; // How many days there has been with 0 rain
    bool public contractActive; // Is the contract currently active, or has it ended
    bool public contractPaid = false;
    uint256 public currentRainfall = 0; // What is the current rainfall for the location
    uint256 public currentRainfallDateChecked = block.timestamp; // When the last rainfall check was performed
    uint256 public requestCount = 0; // How many requests for rainfall data have been made
    uint256 public dataRequestsSent = 0; // Variable used to determine if both requests have been sent
    
    // Premium payment tracking
    bool public premiumPaid = false;
    uint256 public activatedAt = 0;

    /**
     * @dev Prevents a function being run unless it's called by Insurance Provider
     */
    modifier onlyOwner() {
        require(insurer == msg.sender, "Only insurer can do this");
        _;
    }

    /**
     * @dev Prevents a function being run unless the Insurance Contract duration has been reached
     */
    modifier onContractEnded() {
        if (startDate + duration < block.timestamp) {
          _;
        }
    }

    /**
     * @dev Prevents a function being run unless contract is still active
     */
    modifier onContractActive() {
        require(contractActive == true, "Contract ended");
        require(premiumPaid == true, "Premium not paid");
        _;
    }

    /**
     * @dev Prevents a data request to be called unless it's been a day since the last call
     * (to avoid spamming and spoofing results) apply a tolerance of 2/24 of a day or 2 hours.
     */
    modifier callFrequencyOncePerDay() {
        require(
            block.timestamp - currentRainfallDateChecked > (DAY_IN_SECONDS - (DAY_IN_SECONDS / 12)),
            "Can only check rainfall once per day"
        );
        _;
    }

    event contractCreated(address _insurer, address _client, uint _duration, uint _premium, uint _totalCover);
    event contractPaidOut(uint _paidTime, uint _totalPaid, uint _finalRainfall);
    event contractEnded(uint _endTime, uint _totalReturned);
    event contractActivated(uint256 _activatedAt);
    event RainfallThresholdReset(uint256 rainfall);
    event dataRequestSent(bytes32 requestId);
    event dataReceived(uint _rainfall);

    /**
     * @dev Creates a new Insurance contract
     */
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

        //set ETH/USD Price Feed
        priceFeed = AggregatorV3Interface(0x9326BFA02ADD2366b30bacB125260Af641031331);

        //initialize variables required for Chainlink Network interaction
        setChainlinkToken(_link);
        oraclePaymentAmount = _oraclePaymentAmount;

        //first ensure insurer has fully funded the contract (for ETH payments)
        if (_paymentToken == address(0)) {
            require(msg.value >= _payoutValue / uint256(getLatestPrice()), "Not enough funds sent to contract");
        }

        //now initialize values for the contract
        insurer = msg.sender; // This will be the InsuranceProvider contract address
        client = _client;
        startDate = block.timestamp; // Contract will be effective immediately on creation
        duration = _duration;
        premium = _premium;
        payoutValue = _payoutValue;
        paymentToken = _paymentToken;
        daysWithoutRain = 0;
        contractActive = false; // Contract starts inactive until premium is paid
        cropLocation = _cropLocation;

        // Initialize API configuration
        worldWeatherOnlineUrl = "http://api.worldweatheronline.com/premium/v1/weather.ashx?";
        worldWeatherOnlineKey = _worldWeatherKey;
        openWeatherUrl = "https://openweathermap.org/data/2.5/weather?";
        openWeatherKey = _openWeatherKey;
        weatherbitUrl = "https://api.weatherbit.io/v2.0/current?";
        weatherbitKey = _weatherbitKey;

        //set the oracles and jodids to values from nodes on market.link
        oracles[0] = 0x05c8fadf1798437c143683e665800d58a42b6e19;
        oracles[1] = 0x05c8fadf1798437c143683e665800d58a42b6e19;
        jobIds[0] = "a17e8fbf4cbf46eeb79e04b3eb864a4e";
        jobIds[1] = "a17e8fbf4cbf46eeb79e04b3eb864a4e";

        emit ContractCreated(
            insurer,
            client,
            duration,
            premium,
            payoutValue
        );
    }

    /**
     * @dev Activate the contract after premium payment
     * Can only be called by the InsuranceProvider contract
     */
    function activateContract() external onlyOwner {
        require(!contractActive, "Contract already active");
        require(!premiumPaid, "Premium already marked as paid");
        
        premiumPaid = true;
        contractActive = true;
        activatedAt = block.timestamp;
        startDate = block.timestamp; // Reset start date to activation time
        
        emit contractActivated(activatedAt);
    }

    /**
     * @dev Check if the contract is active
     * @return True if contract is active and premium paid
     */
    function isActive() external view returns (bool) {
        return contractActive && premiumPaid;
    }

    /**
     * @dev Check if the contract has ended
     * @return True if contract duration has expired
     */
    function contractEnded() external view returns (bool) {
        return activatedAt > 0 && (activatedAt + duration < block.timestamp);
    }

   /**
     * @dev Calls out to an Oracle to obtain weather data
     */
    function updateContract() public onContractActive() returns (bytes32 requestId)   {
        // First call end contract in case of insurance contract duration expiring,
        // if it hasn't then this function execution will resume
        checkEndContract();

        //contract may have been marked inactive above, only do request if needed
        if (contractActive) {
            dataRequestsSent = 0;
            // First build up a request to World Weather Online to get the current rainfall
            string memory url = string(abi.encodePacked(
                worldWeatherOnlineUrl,
                "key=",
                worldWeatherOnlineKey,
                "&q=",
                cropLocation,
                "&format=json&num_of_days=1"
            ));
            checkRainfall(oracles[0], jobIds[0], url, WORLD_WEATHER_ONLINE_PATH);


            // Now build up the second request to WeatherBit
            url = string(abi.encodePacked(
                weatherbitUrl,
                "city=",
                cropLocation,
                "&key=",
                weatherbitKey
            ));
            checkRainfall(oracles[1], jobIds[1], url, WEATHERBIT_PATH);
        }
    }

    /**
     * @dev Calls out to an Oracle to obtain weather data
     */
    function checkRainfall(
        address _oracle,
        bytes32 _jobId,
        string memory _url,
        string memory _path
    )
        private
        onContractActive()
        returns (bytes32 requestId)
    {

        //First build up a request to get the current rainfall
        Chainlink.Request memory req = buildChainlinkRequest(
            _jobId,
            address(this),
            this.checkRainfallCallBack.selector
        );

        req.add("get", _url); //sends the GET request to the oracle
        req.add("path", _path);
        req.addInt("times", 100);

        requestId = sendChainlinkRequestTo(_oracle, req, oraclePaymentAmount);

        emit dataRequestSent(requestId);
    }


    /**
     * @dev Callback function - This gets called by the Oracle Contract when the Oracle Node passes data back
     * @param _requestId The request ID for fulfillment
     * @param _rainfall The rainfall amount returned
     */
    function checkRainfallCallBack(bytes32 _requestId, uint256 _rainfall) public recordChainlinkFulfillment(_requestId) onContractActive() callFrequencyOncePerDay()  {
        //set current temperature to value returned from Oracle, and store date this was retrieved (to avoid spam and gaming the contract)
        currentRainfallList[dataRequestsSent] = _rainfall;
        currentRainfallDateChecked = block.timestamp;
        requestCount += 1;
        dataRequestsSent += 1;

        //emits that data was received
        emit dataReceived(_rainfall);

        //if we have received both data points, we can aggregate and then evaluate whether to pay out or not
        if (dataRequestsSent > 1) {
            //aggregate the data points
            currentRainfall = (currentRainfallList[0] + currentRainfallList[1]) / 2;

            //check whether the contract conditions have been met, and if so call the payoutcontract function
            if (currentRainfall == 0 ) { //temp threshold has been met
                daysWithoutRain += 1;
            } else {
                //there was rain today, so reset the counter
                daysWithoutRain = 0;
                emit RainfallThresholdReset(currentRainfall);
            }

            if (daysWithoutRain >= DROUGHT_DAYS_THRESHOLD) {  // drought conditions have been met
                //need to pay client out insurance amount
                payOutContract();
            }
        }

     }


    /**
     * @dev Insurance conditions have been met, do payout of total cover amount to client
     */
    function payOutContract() private onContractActive() nonReentrant {

        //Transfer agreed amount to client
        contractPaid = true;
        contractActive = false;
        
        if (paymentToken == address(0)) {
            // ETH payout
            payable(client).transfer(address(this).balance);
        } else {
            // ERC20 token payout
            uint256 tokenBalance = IERC20(paymentToken).balance(address(this));
            IERC20(paymentToken).safeTransfer(client, tokenBalance);
        }

        //Transfer any remaining funds (if any) back to Insurer
        LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
        require(link.transfer(insurer, link.balanceOf(address(this))), "Unable to transfer remaining LINK");
        
        //emit an event that the contract has been paid out
        emit contractPaidOut(block.timestamp, payoutValue, currentRainfall);
    }

    /**
     * @dev Insurance conditions have not been met, and contract expired, end contract and return funds
     */
    function checkEndContract() private onContractEnded() {
        //Insurer needs to have performed at least 1 weather call per day to be eligible to retrieve funds back.
        //We will allow for 1 missed weather call to account for unexpected issues on a given day.
        if (requestCount >= (duration / DAY_IN_SECONDS - 1)) {
            //return funds back to insurance provider then end/kill the contract
            contractActive = false;
            
            if (paymentToken == address(0)) {
                // Return ETH
                payable(insurer).transfer(address(this).balance);
            } else {
                // Return ERC20 tokens
                uint256 tokenBalance = IERC20(paymentToken).balance(address(this));
                IERC20(paymentToken).safeTransfer(insurer, tokenBalance);
            }
        } else { //insurer hasn't done the minimum number of data requests, client is eligible to receive his premium back
            // need to use ETH/USD price feed to calculate ETH amount
            contractActive = false;
            
            uint256 clientRefund = premium / uint256(getLatestPrice());
            payable(client).transfer(clientRefund);
            
            // Return remaining balance to insurer
            if (paymentToken == address(0)) {
                payable(insurer).transfer(address(this).balance);
            } else {
                uint256 tokenBalance = IERC20(paymentToken).balance(address(this));
                IERC20(paymentToken).safeTransfer(insurer, tokenBalance);
            }
        }

        //transfer any remaining LINK tokens back to the insurer
        LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
        require(link.transfer(insurer, link.balanceOf(address(this))), "Unable to transfer remaining LINK");

        //emit an event that the contract has ended
        emit contractEnded(block.timestamp, address(this).balance);
    }


    /**
     * @dev Get the balance of the contract
     * @return _balance The contract balance
     */
    function getContractBalance() external view returns (uint256 _balance) {
        if (paymentToken == address(0)) {
            return address(this).balance;
        } else {
            return IERC20(paymentToken).balanceOf(address(this));
        }
    }

    /**
     * @dev Get the Crop Location
     * @return _location The crop location
     */
    function getLocation() external view returns (string memory _location) {
        return cropLocation;
    }


    /**
     * @dev Get the Total Cover
     * @return _payoutValue The total payout value
     */
    function getPayoutValue() external view returns (uint256 _payoutValue) {
        return payoutValue;
    }


    /**
     * @dev Get the Premium required to be paid
     * @return _premium The premium amount
     */
    function getPremium() external view returns (uint256 _premium) {
        return premium;
    }

    /**
     * @dev Get the status of the contract
     * @return _active Whether the contract is active
     */
    function getContractStatus() external view returns (bool _active) {
        return contractActive;
    }

    /**
     * @dev Get the current recorded rainfall
     * @return _rainfall The current rainfall amount
     */
    function getCurrentRainfall() external view returns (uint256 _rainfall) {
        return currentRainfall;
    }

    /**
     * @dev Get the count of requests that have been made so far for the contract
     * @return _count The number of requests made
     */
    function getRequestCount() external view returns (uint256 _count) {
        return requestCount;
    }

    /**
     * @dev Get the last time that the rainfall was checked for this contract
     * @return _datetime The timestamp of the last check
     */
    function getCurrentRainfallDateChecked() external view returns (uint256 _datetime) {
        return currentRainfallDateChecked;
    }

    /**
     * @dev Get the contract duration
     * @return _duration The duration in seconds
     */
    function getDuration() external view returns (uint256 _duration) {
        return duration;
    }

    /**
     * @dev Get the contract start date
     * @return _startDate The start date timestamp
     */
    function getContractStartDate() external view returns (uint256 _startDate) {
        return startDate;
    }

    /**
     * @dev Get the days without rain
     * @return _days The number of days without rain
     */
    function getDaysWithoutRain() external view returns (uint256 _days) {
        return daysWithoutRain;
    }

    /**
     * @dev Get the address of the chainlink token
     * @return _link The LINK token address
     */
    function getChainlinkToken() public view returns (address _link) {
        return chainlinkTokenAddress();
    }

    /**
     * @dev Helper function for converting a string to a bytes32 object
     * @param _source The source string
     * @return _result The bytes32 result
     */
    function stringToBytes32(string memory _source) private pure returns (bytes32 _result) {
        bytes memory tempEmptyStringTest = bytes(_source);
        if (tempEmptyStringTest.length == 0) {
             return 0x0;
        }
        assembly { // solhint-disable-line no-inline-assembly
            _result := mload(add(_source, 32))
        }
    }


    /**
     * @dev Helper function for returning the latest price from the ETH/USD price feed
     * @return _price The latest price
     */
    function getLatestPrice() public view returns (int256 _price) {
        (
            uint80 roundID,
            int256 price,
            uint256 startedAt,
            uint256 timeStamp,
            uint80 answeredInRound
        ) = priceFeed.latestRoundData();
        // If the round is not complete yet, timestamp is 0
        require(timeStamp > 0, "Round not complete");
        return price;
    }

    /**
     * @dev Fallback function so contrat can receive ether when required
     */
    receive() external payable {  }

}