pragma solidity 0.4.24;
pragma experimental ABIEncoderV2;


//Truffle Imports
import "chainlink/contracts/ChainlinkClient.sol";
import "chainlink/contracts/vendor/Ownable.sol";
import "chainlink/contracts/interfaces/LinkTokenInterface.sol";
import "chainlink/contracts/interfaces/AggregatorInterface.sol";
import "chainlink/contracts/vendor/SafeMathChainlink.sol";
import "chainlink/contracts/interfaces/AggregatorV3Interface.sol";

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 * Simple reentrancy protection for Solidity 0.4.24
 */
contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() internal {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

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




contract InsuranceProvider {

    using SafeMathChainlink for uint256;
    address public insurer = msg.sender;
    AggregatorV3Interface internal priceFeed;

    // How many seconds in a day. 60 for testing, 86400 for Production
    uint256 public constant DAY_IN_SECONDS = 60;

    uint256 private constant ORACLE_PAYMENT = 0.1 * 10**18; // 0.1 LINK
    // Address of LINK token on Kovan
    address public constant LINK_KOVAN = 0xa36085F69e2889c224210F603D836748e7dC0088;

    // Here is where all the insurance contracts are stored.
    mapping(address => InsuranceContract) public contracts;

    // API Keys for weather data
    string public worldWeatherOnlineKey;
    string public openWeatherKey;
    string public weatherbitKey;

    constructor(
        string _worldWeatherKey,
        string _openWeatherKey,
        string _weatherbitKey
    )
        public
        payable
    {
        priceFeed = AggregatorV3Interface(0x9326BFA02ADD2366b30bacB125260Af641031331);
        worldWeatherOnlineKey = _worldWeatherKey;
        openWeatherKey = _openWeatherKey;
        weatherbitKey = _weatherbitKey;
    }

    /**
     * @dev Prevents a function being run unless it's called by the Insurance Provider
     */
    modifier onlyOwner() {
        require(insurer == msg.sender, "Only insurer can do this");
        _;
    }

    /**
     * @dev Event to log when a contract is created
     */
    event ContractCreated(
        address indexed insuranceContract,
        uint256 premium,
        uint256 totalCover
    );


    /**
     * @dev Create a new contract for client, automatically approved and deployed to the blockchain
     * @param _client Address of the client
     * @param _duration Contract duration in seconds
     * @param _premium Premium amount in USD
     * @param _payoutValue Payout value in USD
     * @param _cropLocation Location of the crop for weather data
     * @return Address of the created insurance contract
     */
    function newContract(
        address _client,
        uint256 _duration,
        uint256 _premium,
        uint256 _payoutValue,
        string _cropLocation
    )
        public
        payable
        onlyOwner()
        returns (address)
    {
        // Create contract, send payout amount so contract is fully funded plus a small buffer
        InsuranceContract i = (new InsuranceContract).value(
            (_payoutValue * 1 ether).div(uint256(getLatestPrice()))
        )(
            _client,
            _duration,
            _premium,
            _payoutValue,
            _cropLocation,
            LINK_KOVAN,
            ORACLE_PAYMENT,
            worldWeatherOnlineKey,
            openWeatherKey,
            weatherbitKey
        );

        contracts[address(i)] = i; // Store insurance contract in contracts Map

        // Emit an event to say the contract has been created and funded
        emit ContractCreated(address(i), msg.value, _payoutValue);

        // Now that contract has been created, we need to fund it with enough LINK tokens
        // to fulfil 1 Oracle request per day, with a small buffer added
        LinkTokenInterface link = LinkTokenInterface(i.getChainlinkToken());
        uint256 linkAmount = ((_duration.div(DAY_IN_SECONDS)) + 2) * ORACLE_PAYMENT.mul(2);
        link.transfer(address(i), linkAmount);

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
        selfdestruct(insurer);
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
        ) = priceFeed.latestRoundData();
        // If the round is not complete yet, timestamp is 0
        require(timeStamp > 0, "Round not complete");
        return price;
    }

    /**
     * @dev Fallback function to receive ether
     */
    function() external payable { }

}

contract InsuranceContract is ChainlinkClient, Ownable, ReentrancyGuard {

    using SafeMathChainlink for uint256;
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
    uint256 public currentRainfallDateChecked = now; // When the last rainfall check was performed
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
        if (startDate + duration < now) {
          _;
        }
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
            now.sub(currentRainfallDateChecked) > (DAY_IN_SECONDS.sub(DAY_IN_SECONDS.div(12))),
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
        string _cropLocation,
        address _link,
        uint256 _oraclePaymentAmount,
        string _worldWeatherKey,
        string _openWeatherKey,
        string _weatherbitKey
    )
        public
        payable
        Ownable()
    {

        //set ETH/USD Price Feed
        priceFeed = AggregatorV3Interface(0x9326BFA02ADD2366b30bacB125260Af641031331);

        //initialize variables required for Chainlink Network interaction
        setChainlinkToken(_link);
        oraclePaymentAmount = _oraclePaymentAmount;

        //first ensure insurer has fully funded the contract
        require(msg.value >= _payoutValue.div(uint(getLatestPrice())), "Not enough funds sent to contract");

        //now initialize values for the contract
        insurer= msg.sender;
        client = _client;
        startDate = now ; //contract will be effective immediately on creation
        duration = _duration;
        premium = _premium;
        payoutValue = _payoutValue;
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

        //set the oracles and jodids to values from nodes on market.link
        //oracles[0] = 0x240bae5a27233fd3ac5440b5a598467725f7d1cd;
        //oracles[1] = 0x5b4247e58fe5a54a116e4a3be32b31be7030c8a3;
        //jobIds[0] = "1bc4f827ff5942eaaa7540b7dd1e20b9";
        //jobIds[1] = "e67ddf1f394d44e79a9a2132efd00050";

        //or if you have your own node and job setup you can use it for both requests
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
        string _url,
        string _path
    )
        private
        onContractActive()
        returns (bytes32 requestId)
    {

        //First build up a request to get the current rainfall
        Chainlink.Request memory req = buildChainlinkRequest(\n            _jobId,\n            address(this),\n            this.checkRainfallCallBack.selector\n        );

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
       currentRainfallList[dataRequestsSent] = _rainfall;
       dataRequestsSent = dataRequestsSent + 1;

       //set current rainfall to average of both values
       if (dataRequestsSent > 1) {
          currentRainfall = (currentRainfallList[0].add(currentRainfallList[1]).div(2));
          currentRainfallDateChecked = now;
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
    function payOutContract() private onContractActive() nonReentrant() {
        // CHECKS: Ensure contract is in valid state for payout
        require(contractActive == true, "Contract must be active");
        require(contractPaid == false, "Contract already paid out");
        require(address(this).balance > 0, "No funds available for payout");
        
        // EFFECTS: Update state variables BEFORE external calls
        contractActive = false;
        contractPaid = true;
        
        // Store values for external calls
        uint256 ethBalance = address(this).balance;
        LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
        uint256 linkBalance = link.balanceOf(address(this));
        
        // Emit event with state changes
        emit contractPaidOut(now, payoutValue, currentRainfall);
        
        // INTERACTIONS: External calls AFTER state changes
        // Transfer ETH to client
        client.transfer(ethBalance);
        
        // Transfer remaining LINK tokens back to insurer
        if (linkBalance > 0) {
            require(link.transfer(insurer, linkBalance), "Unable to transfer LINK tokens");
        }
    }

    /**
     * @dev Insurance conditions have not been met, and contract expired, end contract and return funds
     * @dev Protected against reentrancy attacks using nonReentrant modifier and CEI pattern
     */
    function checkEndContract() private onContractEnded() nonReentrant() {
        // CHECKS: Ensure contract can be ended
        require(contractActive == true, "Contract already ended");
        require(startDate + duration < now, "Contract has not expired yet");
        
        // EFFECTS: Update state variables BEFORE external calls
        contractActive = false;
        
        // Calculate amounts and store for external calls
        uint256 ethBalance = address(this).balance;
        LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
        uint256 linkBalance = link.balanceOf(address(this));
        
        // Determine fund distribution
        uint256 clientRefund = 0;
        uint256 insurerAmount = ethBalance;
        
        // Check if insurer met minimum data request requirements
        if (requestCount < (duration.div(DAY_IN_SECONDS) - 2)) {
            // Insurer didn't meet requirements, client gets premium refund
            clientRefund = premium.div(uint(getLatestPrice()));
            if (clientRefund > ethBalance) {
                clientRefund = ethBalance;
            }
            insurerAmount = ethBalance.sub(clientRefund);
        }
        
        // Emit event with final contract state
        emit contractEnded(now, ethBalance);
        
        // INTERACTIONS: External calls AFTER state changes
        // Transfer client refund if applicable
        if (clientRefund > 0) {
            client.transfer(clientRefund);
        }
        
        // Transfer remaining ETH to insurer
        if (insurerAmount > 0) {
            insurer.transfer(insurerAmount);
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
            uint startedAt,
            uint timeStamp,
            uint80 answeredInRound
        ) = priceFeed.latestRoundData();
        // If the round is not complete yet, timestamp is 0
        require(timeStamp > 0, "Round not complete");
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
    function getLocation() external view returns (string) {
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
    function getNow() external view returns (uint) {
        return now;
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
     * @dev Helper function for converting uint to a string
     */
    function uint2str(uint _i) internal pure returns (string memory _uintAsString) {
        if (_i == 0) {
            return "0";
        }
        uint j = _i;
        uint len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint k = len - 1;
        while (_i != 0) {
            bstr[k--] = byte(uint8(48 + _i % 10));
            _i /= 10;
        }
        return string(bstr);
    }

    /**
     * @dev Fallback function so contrat can receive ether when required
     */
    function() external payable {  }


}
