const InsuranceProvider = artifacts.require("InsuranceProvider");
require('dotenv').config();

module.exports = async function(deployer, network) {
  // Get API keys from environment variables
  const worldWeatherOnlineKey = process.env.WORLD_WEATHER_ONLINE_KEY;
  const openWeatherKey = process.env.OPEN_WEATHER_KEY;
  const weatherbitKey = process.env.WEATHERBIT_KEY;

  // Validate that all required API keys are present
  if (!worldWeatherOnlineKey || !openWeatherKey || !weatherbitKey) {
    throw new Error('Missing required API keys in .env file. Please set WORLD_WEATHER_ONLINE_KEY, OPEN_WEATHER_KEY, and WEATHERBIT_KEY');
  }

  console.log('Deploying InsuranceProvider with API keys...');
  console.log('World Weather Online Key:', worldWeatherOnlineKey ? '***' + worldWeatherOnlineKey.slice(-4) : 'NOT SET');
  console.log('OpenWeather Key:', openWeatherKey ? '***' + openWeatherKey.slice(-4) : 'NOT SET');
  console.log('Weatherbit Key:', weatherbitKey ? '***' + weatherbitKey.slice(-4) : 'NOT SET');

  // Deploy the main contract
  await deployer.deploy(
    InsuranceProvider,
    worldWeatherOnlineKey,
    openWeatherKey,
    weatherbitKey
  );

  const provider = await InsuranceProvider.deployed();
  console.log('InsuranceProvider deployed at:', provider.address);

  // Configure supported tokens based on network
  await configureTokens(provider, network);
};

async function configureTokens(provider, network) {
  console.log('\n=== Configuring Supported Tokens ===');
  
  // Token configurations by network
  const tokenConfigs = {
    // Mainnet token addresses and price feeds
    mainnet: {
      USDC: {
        address: '0xA0b86a33E6441d82b90Da6B3Ee1Ba39dFAAE8F2B',
        priceFeed: '0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6' // USDC/USD
      },
      DAI: {
        address: '0x6B175474E89094C44Da98b954EedeAC495271d0F',
        priceFeed: '0xAed0c38402d0d6ded5d0a5A5ec72C5B3F6E1b0b1' // DAI/USD
      },
      USDT: {
        address: '0xdAC17F958D2ee523a2206206994597C13D831ec7',
        priceFeed: '0x3E7d1eAB13ad0104d2750B8863b489D65364e32D' // USDT/USD
      }
    },
    // Sepolia testnet token addresses and price feeds
    sepolia: {
      USDC: {
        address: '0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8', // Sepolia USDC
        priceFeed: '0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E' // USDC/USD on Sepolia
      },
      DAI: {
        address: '0xFF34B3d4Aee8ddCd6F9AFFFB6Fe49bD371b8a357', // Sepolia DAI
        priceFeed: '0x14866185B1962B63C3EA9E03Fb1a9d0c40d90932' // DAI/USD on Sepolia
      }
    },
    // Local development - use mock addresses
    development: {
      USDC: {
        address: '0x1111111111111111111111111111111111111111',
        priceFeed: '0x2222222222222222222222222222222222222222'
      },
      DAI: {
        address: '0x3333333333333333333333333333333333333333',
        priceFeed: '0x4444444444444444444444444444444444444444'
      }
    }
  };

  const networkTokens = tokenConfigs[network] || tokenConfigs.development;

  try {
    for (const [symbol, config] of Object.entries(networkTokens)) {
      console.log(`Adding ${symbol} token...`);
      console.log(`  Token Address: ${config.address}`);
      console.log(`  Price Feed: ${config.priceFeed}`);
      
      await provider.addSupportedToken(config.address, config.priceFeed);
      console.log(`  ✅ ${symbol} token added successfully`);
    }
    
    console.log('\n✅ All supported tokens configured successfully!');
    
    // Display summary
    console.log('\n=== Token Configuration Summary ===');
    console.log(`Network: ${network}`);
    console.log(`Tokens configured: ${Object.keys(networkTokens).join(', ')}`);
    console.log('ETH is always supported by default');
    
  } catch (error) {
    console.error('❌ Error configuring tokens:', error.message);
    console.log('Note: Token configuration failed but contract deployment succeeded.');
    console.log('You can manually configure tokens later using the addSupportedToken function.');
  }
}	