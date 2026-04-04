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

// ReentrancyGuard is now imported from OpenZeppelin

// Remix imports - used when testing in remix
// import "https://github.com/smartcontractkit/chainlink/blob/develop/
//    evm-contracts/src/v0.4/ChainlinkClient.sol";
// import "https://github.com/smartcontractkit/chainlink/blob/develop/
//    evm-contracts/src/v0.4/vendor/Ownable.sol";
// import "https://github.com/smartcontractkit/chainlink/blob/develop/
//    evm-contracts/src/v0.4/interfaces/LinkTokenInterface.sol";
// import "https://github.com/smartcontractkit/chainlink/blob/develop/
//    evm-contracts/src/v0.4/interfaces/AggregatorInterface.sol";
// import "https://github.com/smartcontractkit/chainlink/blob/develop/
//    evm-contracts/src/v0.4/vendor/SafeMathChainlink.sol";
// import "https://github.com/smartcontractkit/chainlink/blob/develop/
//    evm-contracts/src/v0.4/interfaces/AggregatorV3Interface.sol";




contract InsuranceProvider is Ownable {
    using SafeERC20 for IERC20;
    
    // Built-in overflow protection in Solidity 0.8+, no SafeMath needed
    address public insurer;
    AggregatorV3Interface internal ethUsdPriceFeed;

    // How many seconds in a day. 60 for testing, 86400 for Production
    uint256 public constant DAY_IN_SECONDS = 60;
    uint256 public constant MAX_STALENESS = 3600; // 1 hour

    uint256 private constant ORACLE_PAYMENT = 0.1 * 10**18; // 0.1 LINK
    address public immutable linkToken;

    // Oracle configuration
    address public oracle1;
    address public oracle2;
    bytes32 public jobId1;
    bytes32 public jobId2;

    // Here is where all the insurance contracts are stored.
    mapping(address => InsuranceContract) public contracts;
    
    // Supported payment tokens
    mapping(address => bool) public supportedTokens;
    mapping(address => AggregatorV3Interface) public tokenPriceFeeds;
    
    // Common stablecoin addresses (to be set for each network)
    address public USDC;
    address public DAI;
    address public USDT;

    // API Keys for weather data
    string private worldWeatherOnlineKey;
    string private openWeatherKey;
    string private weatherbitKey;

    constructor(
        string memory _worldWeatherKey,
        string memory _openWeatherKey,
        string memory _weatherbitKey,
        address _linkToken,
        address _priceFeed,
        address _oracle1,
        address _oracle2,
        bytes32 _jobId1,
        bytes32 _jobId2
    ) {
        require(_linkToken != address(0), "Invalid LINK address");
        require(_priceFeed != address(0), "Invalid price feed address");
        require(_oracle1 != _oracle2, "Oracles must be different");

        insurer = msg.sender;
        linkToken = _linkToken;
        ethUsdPriceFeed = AggregatorV3Interface(_priceFeed);
        worldWeatherOnlineKey = _worldWeatherKey;
        openWeatherKey = _openWeatherKey;
        weatherbitKey = _weatherbitKey;
        oracle1 = _oracle1;
        oracle2 = _oracle2;
        jobId1 = _jobId1;
        jobId2 = _jobId2;

        // ETH is always supported
        supportedTokens[address(0)] = true;
    }

    function transferOwnership(address newOwner) public override onlyOwner {
        super.transferOwnership(newOwner);
        insurer = newOwner;
    }

    // Using OpenZeppelin's Ownable instead of custom modifier

    /**
     * @dev Event to log when a contract is created
     */
    event ContractCreated(
        address indexed insuranceContract,
        address indexed paymentToken,
        uint256 premium,
        uint256 totalCover
    );
    
    event TokenAdded(address indexed token, address priceFeed);
    event TokenRemoved(address indexed token);


    /**
     * @dev Create a new contract for client, automatically approved and deployed to the blockchain
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
        require(_payoutValue > _premium, "Payout must exceed premium");
        require(_duration > 0, "Duration must be greater than 0");

        // Calculate funding amount based on payment token
        uint256 fundingAmount;
        if (_paymentToken == address(0)) {
            // ETH payment - send ETH to contract
            fundingAmount = (_payoutValue * 1 ether) / uint256(getLatestPrice());
            require(msg.value >= fundingAmount, "Insufficient ETH sent");
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
            linkToken,
            ORACLE_PAYMENT,
            worldWeatherOnlineKey,
            openWeatherKey,
            weatherbitKey,
            address(ethUsdPriceFeed),
            oracle1,
            oracle2,
            jobId1,
            jobId2
        );

        contracts[address(i)] = i; // Store insurance contract in contracts Map
        
        // Handle token transfers based on payment type
        if (_paymentToken != address(0)) {
            // Transfer ERC20 tokens from insurer to the new contract
            uint256 tokenAmount = getTokenAmountForUSD(_paymentToken, _payoutValue);
            IERC20(_paymentToken).safeTransferFrom(msg.sender, address(i), tokenAmount);
        }

        // Emit an event to say the contract has been created and funded
        emit ContractCreated(address(i), _paymentToken, _premium, _payoutValue);

        // Now that contract has been created, we need to fund it with enough LINK tokens
        // to fulfil 1 Oracle request per day, with a small buffer added
        LinkTokenInterface link = LinkTokenInterface(i.getChainlinkToken());
        uint256 linkAmount = ((_duration / DAY_IN_SECONDS) + 2) * ORACLE_PAYMENT * 2;
        require(link.transfer(address(i), linkAmount), "LINK transfer failed");

        return address(i);

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
    function updateContract(address _contract) external onlyOwner {
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
    bool public terminated;

    function endContractProvider() external onlyOwner() {
        require(!terminated, "Already terminated");
        terminated = true;

        LinkTokenInterface link = LinkTokenInterface(linkToken);
        uint256 linkBalance = link.balanceOf(address(this));
        if (linkBalance > 0) {
            require(link.transfer(msg.sender, linkBalance), "Unable to transfer LINK");
        }

        uint256 ethBalance = address(this).balance;
        if (ethBalance > 0) {
            (bool success, ) = payable(insurer).call{value: ethBalance}("");
            require(success, "ETH transfer failed");
        }
    }

    function recoverERC20(address token) external onlyOwner {
        uint256 balance = IERC20(token).balanceOf(address(this));
        require(balance > 0, "No tokens to recover");
        IERC20(token).safeTransfer(insurer, balance);
    }

    /**
     * @dev Returns the latest ETH/USD price from Chainlink oracle
     * @return Latest price with 8 decimal places
     */
    function getLatestPrice() public view returns (int256) {
        (
            uint80 roundID,
            int256 price,
            ,
            uint256 timeStamp,
            uint80 answeredInRound
        ) = ethUsdPriceFeed.latestRoundData();
        require(timeStamp > 0, "Round not complete");
        require(price > 0, "Invalid price");
        require(answeredInRound >= roundID, "Stale price data");
        require(block.timestamp - timeStamp < MAX_STALENESS, "Price feed too stale");
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
        
        (uint80 roundID, int256 price, , uint256 timeStamp, uint80 answeredInRound) = priceFeed.latestRoundData();
        require(timeStamp > 0, "Round not complete");
        require(price > 0, "Invalid price");
        require(answeredInRound >= roundID, "Stale price data");
        require(block.timestamp - timeStamp < MAX_STALENESS, "Price feed too stale");

        uint256 tokenAmount = (usdAmount * 1e18) / uint256(price);
        
        // Adjust for token decimals
        uint8 tokenDecimals = IERC20Metadata(token).decimals();
        if (tokenDecimals < 18) {
            tokenAmount = tokenAmount / 10**(18 - tokenDecimals);
        } else if (tokenDecimals > 18) {
            tokenAmount = tokenAmount * 10**(tokenDecimals - 18);
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
            
            (uint80 roundID, int256 price, , uint256 timeStamp, uint80 answeredInRound) = priceFeed.latestRoundData();
            require(timeStamp > 0, "Round not complete");
            require(price > 0, "Invalid price");
            require(answeredInRound >= roundID, "Stale price data");
            require(block.timestamp - timeStamp < MAX_STALENESS, "Price feed too stale");

            uint8 tokenDecimals = IERC20Metadata(token).decimals();
            if (tokenDecimals < 18) {
                amount = amount * 10**(18 - tokenDecimals);
            } else if (tokenDecimals > 18) {
                amount = amount / 10**(tokenDecimals - 18);
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
    uint256 public constant MAX_STALENESS = 3600; // 1 hour
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
    string private worldWeatherOnlineUrl;
    string private worldWeatherOnlineKey;
    string public constant WORLD_WEATHER_ONLINE_PATH = "data.current_condition.0.precipMM";

    string private openWeatherUrl;
    string private openWeatherKey;
    string public constant OPEN_WEATHER_PATH = "rain.1h";

    string private weatherbitUrl;
    string private weatherbitKey;
    string public constant WEATHERBIT_PATH = "data.0.precip";

    uint256 public daysWithoutRain; // How many days there has been with 0 rain
    bool public contractActive; // Is the contract currently active, or has it ended
    bool public contractPaid = false;
    uint256 public currentRainfall = 0; // What is the current rainfall for the location
    uint256 public currentRainfallDateChecked = block.timestamp; // When the last rainfall check was performed
    uint256 public requestCount = 0; // How many requests for rainfall data have been made
    uint256 public dataRequestsSent = 0; // Variable used to determine if both requests have been sent


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
        require(startDate + duration < block.timestamp, "Contract has not expired");
        _;
    }

    /**
     * @dev Prevents a function being run unless contract is still active
     */
    modifier onContractActive() {
        require(contractActive == true, "Contract ended");
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
        string memory _weatherbitKey,
        address _priceFeed,
        address _oracle1,
        address _oracle2,
        bytes32 _jobId1,
        bytes32 _jobId2
    ) {
        require(_oracle1 != _oracle2, "Oracles must be different");

        //set ETH/USD Price Feed
        priceFeed = AggregatorV3Interface(_priceFeed);

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
        contractActive = true;
        cropLocation = _cropLocation;

        // Initialize API configuration
        worldWeatherOnlineUrl = "http://api.worldweatheronline.com/premium/v1/weather.ashx?";
        worldWeatherOnlineKey = _worldWeatherKey;
        openWeatherUrl = "https://openweathermap.org/data/2.5/weather?";
        openWeatherKey = _openWeatherKey;
        weatherbitUrl = "https://api.weatherbit.io/v2.0/current?";
        weatherbitKey = _weatherbitKey;

        //set the oracles and jobIds from constructor parameters
        oracles[0] = _oracle1;
        oracles[1] = _oracle2;
        jobIds[0] = _jobId1;
        jobIds[1] = _jobId2;

        emit ContractCreated(
            insurer,
            client,
            duration,
            premium,
            payoutValue
        );
    }

   /**
     * @dev Calls out to an Oracle to obtain weather data
     */
    function updateContract() public onlyOwner() onContractActive() returns (bytes32 requestId)   {
        // Check if contract duration has expired
        if (startDate + duration < block.timestamp) {
            checkEndContract();
            return bytes32(0);
        }

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
     * @dev Callback function - This gets called by the Oracle Contract when the Oracle Node
     * passes data back to the Oracle Contract. The function will take the rainfall given by
     * the Oracle and update the Insurance Contract state
     */
    function checkRainfallCallBack(
        bytes32 _requestId,
        uint256 _rainfall
    )
        public
        recordChainlinkFulfillment(_requestId)
        onContractActive()
        callFrequencyOncePerDay()
        nonReentrant()
    {
        //set current temperature to value returned from Oracle, and store date this was retrieved (to avoid spam and gaming the contract)
       require(dataRequestsSent < 2, "Unexpected extra callback");
       currentRainfallList[dataRequestsSent] = _rainfall;
       dataRequestsSent = dataRequestsSent + 1;

       //set current rainfall to average of both values
       if (dataRequestsSent > 1) {
          currentRainfall = (currentRainfallList[0] + currentRainfallList[1]) / 2;
          currentRainfallDateChecked = block.timestamp;
          requestCount +=1;

          //check if payout conditions have been met, if so call payoutcontract, which should also end/kill contract at the end
          if (currentRainfall == 0 ) { //temp threshold has been  met, add a day of over threshold
              daysWithoutRain += 1;
          } else {
              //there was rain today, so reset daysWithoutRain parameter
              daysWithoutRain = 0;
              emit RainfallThresholdReset(currentRainfall);
          }

          if (daysWithoutRain >= DROUGHT_DAYS_THRESHOLD) {  // day threshold has been met
              //need to pay client out insurance amount
              payOutContract();
          }
       }

       emit dataReceived(_rainfall);

    }


    /**
     * @dev Insurance conditions have been met, do payout of total cover amount to client
     * @dev Protected against reentrancy attacks using nonReentrant modifier and CEI pattern
     */
    function payOutContract() private onContractActive() {
        // CHECKS: Ensure contract is in valid state for payout
        require(contractActive == true, "Contract must be active");
        require(contractPaid == false, "Contract already paid out");
        
        // EFFECTS: Update state variables BEFORE external calls
        contractActive = false;
        contractPaid = true;
        
        // Store values for external calls
        LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
        uint256 linkBalance = link.balanceOf(address(this));
        
        // Emit event with state changes
        emit contractPaidOut(block.timestamp, payoutValue, currentRainfall);
        
        // INTERACTIONS: External calls AFTER state changes
        // Transfer payout based on payment token type
        if (paymentToken == address(0)) {
            // ETH payout
            require(address(this).balance > 0, "No ETH funds available");
            (bool success, ) = payable(client).call{value: address(this).balance}("");
            require(success, "ETH transfer failed");
        } else {
            // ERC20 token payout
            IERC20 token = IERC20(paymentToken);
            uint256 tokenBalance = token.balanceOf(address(this));
            require(tokenBalance > 0, "No token funds available");
            SafeERC20.safeTransfer(token, client, tokenBalance);
        }
        
        // Transfer remaining LINK tokens back to insurer
        if (linkBalance > 0) {
            require(link.transfer(insurer, linkBalance), "Unable to transfer LINK tokens");
        }
    }

    /**
     * @dev Insurance conditions have not been met, and contract expired, end contract and return funds
     * @dev Protected against reentrancy attacks using nonReentrant modifier and CEI pattern
     */
    function checkEndContract() private onContractEnded() {
        // CHECKS: Ensure contract can be ended
        require(contractActive == true, "Contract already ended");
        require(startDate + duration < block.timestamp, "Contract has not expired yet");
        
        // EFFECTS: Update state variables BEFORE external calls
        contractActive = false;
        
        // Store LINK balance for later transfer
        LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
        uint256 linkBalance = link.balanceOf(address(this));
        
        // Emit event before transfers
        emit contractEnded(block.timestamp, 0);
        
        // INTERACTIONS: External calls AFTER state changes
        if (paymentToken == address(0)) {
            // ETH payment flow
            uint256 ethBalance = address(this).balance;
            uint256 clientRefund = 0;
            uint256 insurerAmount = ethBalance;

            // Check if insurer met minimum data request requirements
            uint256 minRequests = duration >= 2 * DAY_IN_SECONDS ? (duration / DAY_IN_SECONDS - 2) : 0;
            if (requestCount < minRequests) {
                // Insurer didn't meet requirements, client gets proportional ETH refund
                clientRefund = (ethBalance * premium) / payoutValue;
                if (clientRefund > ethBalance) {
                    clientRefund = ethBalance;
                }
                insurerAmount = ethBalance - clientRefund;
            }
            
            // Transfer ETH refunds
            if (clientRefund > 0) {
                (bool success1, ) = payable(client).call{value: clientRefund}("");
                require(success1, "ETH transfer failed");
            }
            
            if (insurerAmount > 0) {
                (bool success2, ) = payable(insurer).call{value: insurerAmount}("");
                require(success2, "ETH transfer failed");
            }
        } else {
            // ERC20 token payment flow
            IERC20 token = IERC20(paymentToken);
            uint256 tokenBalance = token.balanceOf(address(this));
            uint256 clientRefund = 0;
            uint256 insurerAmount = tokenBalance;

            // Check if insurer met minimum data request requirements
            uint256 minTokenRequests = duration >= 2 * DAY_IN_SECONDS ? (duration / DAY_IN_SECONDS - 2) : 0;
            if (requestCount < minTokenRequests) {
                // Refund proportional to premium/payoutValue ratio
                clientRefund = (tokenBalance * premium) / payoutValue;
                if (clientRefund > tokenBalance) {
                    clientRefund = tokenBalance;
                }
                insurerAmount = tokenBalance - clientRefund;
            }
            
            // Transfer token refunds using SafeERC20
            if (clientRefund > 0) {
                token.safeTransfer(client, clientRefund);
            }
            
            if (insurerAmount > 0) {
                token.safeTransfer(insurer, insurerAmount);
            }
        }
        
        // Transfer remaining LINK tokens back to insurer
        if (linkBalance > 0) {
            require(link.transfer(insurer, linkBalance), "Unable to transfer remaining LINK tokens");
        }
    }

    /**
     * Returns the latest price
     */
    function getLatestPrice() public view returns (int) {
        (
            uint80 roundID,
            int price,
            ,
            uint timeStamp,
            uint80 answeredInRound
        ) = priceFeed.latestRoundData();
        require(timeStamp > 0, "Round not complete");
        require(price > 0, "Invalid price");
        require(answeredInRound >= roundID, "Stale price data");
        require(block.timestamp - timeStamp < MAX_STALENESS, "Price feed too stale");
        return price;
    }


    /**
     * @dev Get the balance of the contract
     */
    function getContractBalance() external view returns (uint) {
        return address(this).balance;
    }

    /**
     * @dev Get the Crop Location
     */
    function getLocation() external view returns (string memory) {
        return cropLocation;
    }


    /**
     * @dev Get the Total Cover
     */
    function getPayoutValue() external view returns (uint) {
        return payoutValue;
    }


    /**
     * @dev Get the Premium paid
     */
    function getPremium() external view returns (uint) {
        return premium;
    }

    /**
     * @dev Get the status of the contract
     */
    function getContractStatus() external view returns (bool) {
        return contractActive;
    }

    /**
     * @dev Get whether the contract has been paid out or not
     */
    function getContractPaid() external view returns (bool) {
        return contractPaid;
    }


    /**
     * @dev Get the current recorded rainfall for the contract
     */
    function getCurrentRainfall() external view returns (uint) {
        return currentRainfall;
    }

    /**
     * @dev Get the recorded number of days without rain
     */
    function getDaysWithoutRain() external view returns (uint) {
        return daysWithoutRain;
    }

    /**
     * @dev Get the count of requests that has occured for the Insurance Contract
     */
    function getRequestCount() external view returns (uint) {
        return requestCount;
    }

    /**
     * @dev Get the last time that the rainfall was checked for the contract
     */
    function getCurrentRainfallDateChecked() external view returns (uint) {
        return currentRainfallDateChecked;
    }

    /**
     * @dev Get the contract duration
     */
    function getDuration() external view returns (uint) {
        return duration;
    }

    /**
     * @dev Get the contract start date
     */
    function getContractStartDate() external view returns (uint) {
        return startDate;
    }

    /**
     * @dev Get the current date/time according to the blockchain
     */
    function getNow() external view returns (uint256) {
        return block.timestamp;
    }

    /**
     * @dev Get address of the chainlink token
     */
    function getChainlinkToken() public view returns (address) {
        return chainlinkTokenAddress();
    }

    /**
     * @dev Helper function for converting a string to a bytes32 object
     */
    function stringToBytes32(string memory source) private pure returns (bytes32 result) {
        bytes memory tempEmptyStringTest = bytes(source);
        if (tempEmptyStringTest.length == 0) {
         return 0x0;
        }

        assembly { // solhint-disable-line no-inline-assembly
        result := mload(add(source, 32))
        }
    }


    /**
     * @dev Fallback function so contract can receive ether when required
     */
    receive() external payable { }
    
    fallback() external payable { }


}
