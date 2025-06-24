// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockERC20
 * @dev Mock ERC20 token for testing
 */
contract MockERC20 is ERC20 {
    uint8 private _decimals;
    
    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals_
    ) ERC20(name, symbol) {
        _decimals = decimals_;
    }
    
    function decimals() public view override returns (uint8) {
        return _decimals;
    }
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
    
    function burn(address from, uint256 amount) external {
        _burn(from, amount);
    }
}

/**
 * @title MockAggregatorV3
 * @dev Mock Chainlink price feed for testing
 */
contract MockAggregatorV3 {
    int256 private _price;
    uint8 private _decimals;
    uint256 private _updatedAt;
    
    constructor(int256 initialPrice, uint8 decimals_) {
        _price = initialPrice;
        _decimals = decimals_;
        _updatedAt = block.timestamp;
    }
    
    function decimals() external view returns (uint8) {
        return _decimals;
    }
    
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return (
            1,
            _price,
            block.timestamp - 100,
            _updatedAt,
            1
        );
    }
    
    function setPrice(int256 newPrice) external {
        _price = newPrice;
        _updatedAt = block.timestamp;
    }
    
    function setStaleData() external {
        _updatedAt = 0; // Make data stale
    }
}

/**
 * @title MockLinkToken
 * @dev Mock LINK token for testing
 */
contract MockLinkToken is ERC20 {
    constructor() ERC20("ChainLink Token", "LINK") {}
    
    function decimals() public pure override returns (uint8) {
        return 18;
    }
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
    
    function transfer(address to, uint256 amount) public override returns (bool) {
        // Override to always return true for testing
        _transfer(_msgSender(), to, amount);
        return true;
    }
    
    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        // Override to always return true for testing
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }
}

/**
 * @title MockOracle
 * @dev Mock Chainlink oracle for testing
 */
contract MockOracle {
    mapping(bytes32 => bool) public pendingRequests;
    mapping(bytes32 => uint256) public responses;
    
    event OracleRequest(
        bytes32 indexed requestId,
        address requester,
        bytes32 jobId,
        string url
    );
    
    event OracleResponse(
        bytes32 indexed requestId,
        uint256 data
    );
    
    function oracleRequest(
        address sender,
        uint256 payment,
        bytes32 specId,
        address callbackAddress,
        bytes4 callbackFunctionId,
        uint256 nonce,
        uint256 dataVersion,
        bytes calldata data
    ) external {
        bytes32 requestId = keccak256(abi.encodePacked(sender, nonce));
        pendingRequests[requestId] = true;
        
        emit OracleRequest(requestId, sender, specId, string(data));
    }
    
    function fulfillOracleRequest(bytes32 requestId, uint256 data) external {
        require(pendingRequests[requestId], "Request not found");
        pendingRequests[requestId] = false;
        responses[requestId] = data;
        
        emit OracleResponse(requestId, data);
    }
    
    function simulateResponse(bytes32 requestId, uint256 data, address callbackAddress) external {
        require(pendingRequests[requestId], "Request not found");
        pendingRequests[requestId] = false;
        responses[requestId] = data;
        
        // Call the callback function
        (bool success,) = callbackAddress.call(
            abi.encodeWithSignature("checkRainfallCallBack(bytes32,uint256)", requestId, data)
        );
        require(success, "Callback failed");
        
        emit OracleResponse(requestId, data);
    }
}