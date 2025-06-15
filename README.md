# Decentralized Crop Insurance 

A secure, decentralized crop insurance product built on Ethereum that uses Chainlink Oracles to obtain weather data from multiple external APIs for automated drought-based payouts.

## 🚀 Features

- **Automated Payouts**: Smart contracts automatically trigger insurance payouts when drought conditions are detected
- **Multi-Oracle Integration**: Weather data aggregated from multiple APIs (World Weather Online, WeatherBit, OpenWeather) for reliability  
- **Secure Architecture**: Protected against reentrancy attacks with comprehensive security measures
- **Configurable Parameters**: Flexible contract terms for different agricultural needs
- **Production-Ready**: Enhanced with proper error handling, input validation, and gas optimization

## 🔒 Security Improvements

This implementation includes several critical security enhancements:

### ✅ **Fixed Critical Vulnerabilities**
- **API Key Exposure**: Removed hardcoded API keys from smart contracts (CRITICAL fix)
- **Reentrancy Attacks**: Implemented ReentrancyGuard and Checks-Effects-Interactions pattern
- **Input Validation**: Added comprehensive parameter validation and error handling
- **Code Quality**: Fixed 40+ linting issues and improved code maintainability

### 🛡️ **Security Features**
- Custom ReentrancyGuard for Solidity 0.4.24 compatibility
- Proper state management with atomic operations  
- Safe external call patterns with balance validation
- Comprehensive access controls and modifiers

## 📋 Prerequisites

- Node.js v14+ and npm
- Truffle Suite
- MetaMask or similar Web3 wallet
- Weather API keys (see Environment Setup)

## ⚙️ Environment Setup

Create a `.env` file in the root directory:

```bash
# Weather API Keys (REQUIRED for deployment)
WORLD_WEATHER_ONLINE_KEY=your_world_weather_online_api_key
OPEN_WEATHER_KEY=your_openweather_api_key  
WEATHERBIT_KEY=your_weatherbit_api_key

# Blockchain Configuration
MNEMONIC=your_wallet_seed_phrase
MAINNET_RPC_URL=https://mainnet.infura.io/v3/your-infura-key
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/your-infura-key

# Oracle Configuration (Optional - uses defaults if not set)
ORACLE_PAYMENT=0.1
LINK_TOKEN_ADDRESS=0xa36085F69e2889c224210F603D836748e7dC0088
```

### 🔑 **Getting API Keys**

1. **World Weather Online**: Sign up at [worldweatheronline.com](https://www.worldweatheronline.com/developer/)
2. **OpenWeather**: Get key at [openweathermap.org](https://openweathermap.org/api)  
3. **WeatherBit**: Register at [weatherbit.io](https://www.weatherbit.io/api)

## 🚀 Installation & Deployment

### 1. Install Dependencies
```bash
# Install packages
npm install

# Install additional dependencies (if needed)
npm install dotenv --save
```

### 2. Compile Contracts
```bash
# Compile smart contracts
npm run compile
# or
truffle compile
```

### 3. Deploy to Network
```bash
# Deploy to local development network
npm run migrate:dev

# Deploy to Sepolia testnet  
truffle migrate --network sepolia

# Deploy to mainnet (production)
truffle migrate --network mainnet
```

## 🏗️ Contract Architecture

### **InsuranceProvider** (Master Contract)
- Creates and manages individual insurance contracts
- Handles funding and LINK token distribution
- Configurable with weather API keys during deployment
- Administrative functions for contract management

### **InsuranceContract** (Individual Policies)
- Tracks weather data from multiple oracle sources
- Implements drought detection logic (3+ consecutive days without rain)
- Automatic payout execution when conditions are met
- Protected against reentrancy and manipulation attacks

### **ReentrancyGuard** (Security Module)
- Custom implementation for Solidity 0.4.24
- Prevents recursive calls and double-spending attacks
- Applied to all critical state-changing functions

## 🧪 Testing

```bash
# Run all tests
npm test

# Run specific test file
truffle test test/MyContract_test.js

# Run reentrancy protection tests
truffle test test/reentrancy-test.js
```

## 🔧 Development Commands

```bash
# Lint Solidity code
npm run lint

# Start Truffle console
npm run console:dev   # Local development
npm run console:live  # Live network

# Check dependencies
npm run depcheck
```

## 📊 How It Works

1. **Policy Creation**: Insurance provider creates policy with specific terms
2. **Funding**: Contract is funded with ETH (for payouts) and LINK (for oracle requests)
3. **Weather Monitoring**: Daily oracle requests aggregate weather data from multiple sources
4. **Drought Detection**: Contract tracks consecutive days without rainfall
5. **Automatic Payout**: When drought threshold (3+ days) is met, payout is automatically triggered
6. **Contract Completion**: Contract ends after duration expires or payout is made

## 🌐 Network Configuration

### Supported Networks
- **Local Development**: Ganache (127.0.0.1:7545)
- **Testnet**: Sepolia (recommended over deprecated Kovan)
- **Mainnet**: Ethereum mainnet for production deployment

### Oracle Integration
- Uses Chainlink Price Feeds for ETH/USD conversion
- Configurable oracle nodes and job IDs
- Support for custom oracle setups

## 📖 Documentation References

- [Chainlink Official Documentation](https://docs.chain.link/)
- [Technical Article](https://blog.chain.link/decentralized-insurance-product) on Chainlink blog
- [Truffle Documentation](https://trufflesuite.com/docs/)

## 🤝 Contract Interaction

Once deployed, you can interact with the contracts using:

- [MyEtherWallet](https://www.myetherwallet.com/interface/interact-with-contract)
- [Etherscan](https://etherscan.io/) contract interface
- Custom DApp frontend
- Truffle console commands

### Example Contract Calls
```javascript
// Get contract status
await insuranceContract.getContractStatus()

// Get current rainfall data  
await insuranceContract.getCurrentRainfall()

// Check contract balance
await insuranceContract.getContractBalance()
```

## ⚠️ Important Notes

- **Security**: API keys are now securely managed via environment variables
- **Network**: Update from deprecated Kovan to Sepolia testnet
- **Testing**: Always test thoroughly on testnet before mainnet deployment
- **Gas Costs**: Monitor gas prices and optimize for cost-effective deployment
- **Oracle Reliability**: Ensure multiple oracle sources for data redundancy

## 🐛 Troubleshooting

### Common Issues

1. **Missing API Keys**: Ensure all required API keys are set in `.env`
2. **Network Issues**: Check RPC URLs and network configuration
3. **Gas Estimation**: Increase gas limit for complex contract interactions
4. **Oracle Failures**: Verify oracle node availability and job IDs

### Getting Help

- Check [Issues](../../issues) for known problems
- Review [CLAUDE.md](./CLAUDE.md) for development guidance
- Consult Chainlink documentation for oracle-related issues

## 📄 License

MIT License - see [LICENSE](./LICENSE) file for details.

---

**⚡ Enhanced Security**: This version includes critical security fixes and is recommended for production use over the original implementation.
