const InsuranceProvider = artifacts.require("InsuranceProvider");

module.exports = async function(deployer, network, accounts) {
  console.log("Deploying Insurance Provider with Premium Collection...");
  console.log("Network:", network);
  console.log("Deployer:", accounts[0]);

  // Validate API keys from environment
  const worldWeatherKey = process.env.WORLD_WEATHER_ONLINE_KEY;
  const openWeatherKey = process.env.OPEN_WEATHER_KEY;
  const weatherbitKey = process.env.WEATHERBIT_KEY;

  if (!worldWeatherKey || !openWeatherKey || !weatherbitKey) {
    console.error("Missing required API keys in environment variables:");
    console.error("WORLD_WEATHER_ONLINE_KEY:", !!worldWeatherKey);
    console.error("OPEN_WEATHER_KEY:", !!openWeatherKey);
    console.error("WEATHERBIT_KEY:", !!weatherbitKey);
    throw new Error("Please set all required API keys in .env file");
  }

  console.log("API keys validated ✓");

  // Deploy InsuranceProvider with API keys
  await deployer.deploy(
    InsuranceProvider,
    worldWeatherKey,
    openWeatherKey,
    weatherbitKey
  );

  const provider = await InsuranceProvider.deployed();
  console.log("InsuranceProvider deployed at:", provider.address);

  // Configure supported tokens based on network
  if (network === 'mainnet') {
    console.log("Configuring mainnet tokens...");
    
    // Mainnet token configurations
    const tokens = {
      USDC: {
        address: '0xA0b86a33E6441d82b90Da6B3Ee1Ba39dFAAE8F2B',
        priceFeed: '0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6' // USDC/USD
      },
      DAI: {
        address: '0x6B175474E89094C44Da98b954EedeAC495271d0F',
        priceFeed: '0xAed0c38402b1c3cC8b6b5De9DB4Cf3f96E9F39Ec' // DAI/USD
      },
      USDT: {
        address: '0xdAC17F958D2ee523a2206206994597C13D831ec7',
        priceFeed: '0x3E7d1eAB13ad0104d2750B8863b489D65364e32D' // USDT/USD
      }
    };

    for (const [symbol, config] of Object.entries(tokens)) {
      try {
        await provider.addSupportedToken(config.address, config.priceFeed);
        console.log(`✓ Added ${symbol} token support`);
      } catch (error) {
        console.error(`✗ Failed to add ${symbol}:`, error.message);
      }
    }

  } else if (network === 'sepolia') {
    console.log("Configuring Sepolia testnet tokens...");
    
    // Sepolia testnet token configurations
    const tokens = {
      USDC: {
        address: '0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8',
        priceFeed: '0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E' // USDC/USD on Sepolia
      },
      DAI: {
        address: '0xFF34B3d4Aee8ddCd6F9AFFFB6Fe49bD371b8a357',
        priceFeed: '0x14866185B1962B63C3Ea9E03Bc1da838bab34C19' // DAI/USD on Sepolia
      }
    };

    for (const [symbol, config] of Object.entries(tokens)) {
      try {
        await provider.addSupportedToken(config.address, config.priceFeed);
        console.log(`✓ Added ${symbol} token support`);
      } catch (error) {
        console.error(`✗ Failed to add ${symbol}:`, error.message);
      }
    }

  } else {
    console.log("Development network - using mock tokens");
    console.log("Tokens can be added manually via addSupportedToken()");
  }

  // Display contract information
  console.log("\n=== Deployment Summary ===");
  console.log(`Network: ${network}`);
  console.log(`InsuranceProvider: ${provider.address}`);
  console.log(`Deployer: ${accounts[0]}`);
  console.log(`ETH Balance: ${web3.utils.fromWei(await web3.eth.getBalance(accounts[0]))} ETH`);
  
  // Display important addresses
  console.log("\n=== Important Information ===");
  console.log("• Clients must pay premiums within 24 hours of contract creation");
  console.log("• Contracts only activate after premium payment");
  console.log("• Premiums can be refunded if contracts never activate");
  console.log("• Insurers can claim premiums after contracts end");
  
  console.log("\n=== Next Steps ===");
  console.log("1. Fund the contract with LINK tokens for oracle requests");
  console.log("2. Create insurance contracts via newContract()");
  console.log("3. Clients pay premiums via payPremium()");
  console.log("4. Monitor contracts and handle weather data updates");
  console.log("5. Claim premiums after contracts expire or complete");

  console.log("\n✅ Premium Collection System Deployed Successfully!");
};