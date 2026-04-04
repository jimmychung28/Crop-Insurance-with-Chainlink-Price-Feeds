const AutomatedInsuranceProvider = artifacts.require("AutomatedInsuranceProvider");

module.exports = async function(deployer, network, accounts) {
  console.log("🚀 Deploying Automated Insurance System with Chainlink Automation...");
  console.log("Network:", network);
  console.log("Deployer:", accounts[0]);

  // Validate API keys from environment
  const worldWeatherKey = process.env.WORLD_WEATHER_ONLINE_KEY;
  const openWeatherKey = process.env.OPEN_WEATHER_KEY;
  const weatherbitKey = process.env.WEATHERBIT_KEY;

  if (!worldWeatherKey || !openWeatherKey || !weatherbitKey) {
    console.error("❌ Missing required API keys in environment variables:");
    console.error("WORLD_WEATHER_ONLINE_KEY:", !!worldWeatherKey);
    console.error("OPEN_WEATHER_KEY:", !!openWeatherKey);
    console.error("WEATHERBIT_KEY:", !!weatherbitKey);
    throw new Error("Please set all required API keys in .env file");
  }

  console.log("API keys validated");

  // Network-specific addresses
  const networkConfig = {
    mainnet: {
      linkToken: '0x514910771AF9Ca656af840dff83E8264EcF986CA',
      ethUsdFeed: '0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419',
      oracle1: process.env.ORACLE_ADDRESS_1,
      oracle2: process.env.ORACLE_ADDRESS_2,
      jobId1: process.env.JOB_ID_1,
      jobId2: process.env.JOB_ID_2
    },
    sepolia: {
      linkToken: '0x779877A7B0D9E8603169DdbD7836e478b4624789',
      ethUsdFeed: '0x694AA1769357215DE4FAC081bf1f309aDC325306',
      oracle1: process.env.ORACLE_ADDRESS_1 || '0x6090149792dAAeE9D1D568c9f9a6F6B46AA29eFD',
      oracle2: process.env.ORACLE_ADDRESS_2 || '0x6090149792dAAeE9D1D568c9f9a6F6B46AA29eFD',
      jobId1: process.env.JOB_ID_1 || '0x' + '0'.repeat(64),
      jobId2: process.env.JOB_ID_2 || '0x' + '0'.repeat(64)
    },
    development: {
      linkToken: '0xa36085F69e2889c224210F603D836748e7dC0088',
      ethUsdFeed: '0x9326BFA02ADD2366b30bacB125260Af641031331',
      oracle1: '0x05c8FaDf1798437c143683E665800D58a42b6E19',
      oracle2: '0x240Bae5a27233fD3Ac5440b5A598467725f7d1cD',
      jobId1: '0x' + '0'.repeat(64),
      jobId2: '0x' + '0'.repeat(64)
    }
  };

  const config = networkConfig[network] || networkConfig.development;
  console.log("LINK Token:", config.linkToken);
  console.log("ETH/USD Feed:", config.ethUsdFeed);

  // Deploy AutomatedInsuranceProvider
  await deployer.deploy(
    AutomatedInsuranceProvider,
    worldWeatherKey,
    openWeatherKey,
    weatherbitKey,
    config.linkToken,
    config.ethUsdFeed,
    config.oracle1,
    config.oracle2,
    config.jobId1,
    config.jobId2
  );

  const provider = await AutomatedInsuranceProvider.deployed();
  console.log("✅ AutomatedInsuranceProvider deployed at:", provider.address);

  // Configure supported tokens based on network
  if (network === 'mainnet') {
    console.log("🔧 Configuring mainnet tokens...");
    
    const tokens = {
      USDC: {
        address: '0xA0b86a33E6441d82b90Da6B3Ee1Ba39dFAAE8F2B',
        priceFeed: '0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6'
      },
      DAI: {
        address: '0x6B175474E89094C44Da98b954EedeAC495271d0F',
        priceFeed: '0xAed0c38402b1c3cC8b6b5De9DB4Cf3f96E9F39Ec'
      },
      USDT: {
        address: '0xdAC17F958D2ee523a2206206994597C13D831ec7',
        priceFeed: '0x3E7d1eAB13ad0104d2750B8863b489D65364e32D'
      }
    };

    for (const [symbol, config] of Object.entries(tokens)) {
      try {
        await provider.addSupportedToken(config.address, config.priceFeed);
        console.log(`✅ Added ${symbol} token support`);
      } catch (error) {
        console.error(`❌ Failed to add ${symbol}:`, error.message);
      }
    }

  } else if (network === 'sepolia') {
    console.log("🔧 Configuring Sepolia testnet tokens...");
    
    const tokens = {
      USDC: {
        address: '0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8',
        priceFeed: '0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E'
      },
      DAI: {
        address: '0xFF34B3d4Aee8ddCd6F9AFFFB6Fe49bD371b8a357',
        priceFeed: '0x14866185B1962B63C3Ea9E03Bc1da838bab34C19'
      }
    };

    for (const [symbol, config] of Object.entries(tokens)) {
      try {
        await provider.addSupportedToken(config.address, config.priceFeed);
        console.log(`✅ Added ${symbol} token support`);
      } catch (error) {
        console.error(`❌ Failed to add ${symbol}:`, error.message);
      }
    }

  } else {
    console.log("🧪 Development network - tokens can be added manually");
  }

  // Get automation configuration details
  const automationEnabled = await provider.automationEnabled();
  const upkeepInterval = await provider.upkeepInterval();
  const activeContractsCount = await provider.getActiveContractsCount();

  // Display deployment summary
  console.log("\n" + "=".repeat(60));
  console.log("🎉 AUTOMATED INSURANCE SYSTEM DEPLOYMENT COMPLETE");
  console.log("=".repeat(60));
  
  console.log("\n📊 Contract Information:");
  console.log(`   • Network: ${network}`);
  console.log(`   • AutomatedInsuranceProvider: ${provider.address}`);
  console.log(`   • Deployer: ${accounts[0]}`);
  console.log(`   • ETH Balance: ${web3.utils.fromWei(await web3.eth.getBalance(accounts[0]))} ETH`);
  
  console.log("\n⚙️  Automation Configuration:");
  console.log(`   • Automation Enabled: ${automationEnabled}`);
  console.log(`   • Upkeep Interval: ${upkeepInterval} seconds (${upkeepInterval/86400} days)`);
  console.log(`   • Active Contracts: ${activeContractsCount}`);
  console.log(`   • Max Batch Size: 10 contracts per upkeep`);

  console.log("\n🔗 Chainlink Integration:");
  console.log("   • Implements AutomationCompatibleInterface");
  console.log("   • checkUpkeep() - Determines if weather monitoring needed");
  console.log("   • performUpkeep() - Executes automated weather checks");
  console.log("   • Batch processing for gas efficiency");

  console.log("\n✨ Key Features:");
  console.log("   ✅ Automated daily weather monitoring");
  console.log("   ✅ Gas-efficient batch processing");
  console.log("   ✅ Premium collection with escrow");
  console.log("   ✅ Multi-token support (ETH, USDC, DAI, USDT)");
  console.log("   ✅ Chainlink Automation v2.1+ compatible");
  console.log("   ✅ Automatic contract lifecycle management");
  console.log("   ✅ Emergency manual override functions");

  // Chainlink Automation Registration Instructions
  console.log("\n" + "=".repeat(60));
  console.log("🔧 CHAINLINK AUTOMATION SETUP INSTRUCTIONS");
  console.log("=".repeat(60));

  if (network === 'mainnet') {
    console.log("\n📍 Mainnet Registration:");
    console.log("   1. Visit: https://automation.chain.link/");
    console.log("   2. Connect your wallet");
    console.log("   3. Click 'Register new Upkeep'");
    console.log(`   4. Enter contract address: ${provider.address}`);
    console.log("   5. Select 'Custom logic' trigger");
    console.log("   6. Set upkeep name: 'Crop Insurance Weather Monitoring'");
    console.log("   7. Fund with LINK tokens (recommended: 10-50 LINK)");
    console.log("   8. Set gas limit: 2,000,000");
    console.log("   9. Complete registration");

  } else if (network === 'sepolia') {
    console.log("\n🧪 Sepolia Testnet Registration:");
    console.log("   1. Visit: https://automation.chain.link/sepolia");
    console.log("   2. Connect your wallet");
    console.log("   3. Get testnet LINK: https://faucets.chain.link/");
    console.log("   4. Register upkeep with contract address");
    console.log(`   5. Contract: ${provider.address}`);
    console.log("   6. Fund with 5-10 testnet LINK");

  } else {
    console.log("\n🏠 Local Development:");
    console.log("   • Automation testing available via manual triggers");
    console.log("   • Use manualWeatherUpdate() for testing");
    console.log("   • Deploy to testnet for full automation testing");
  }

  console.log("\n📋 Post-Deployment Checklist:");
  console.log("   □ Register upkeep on Chainlink Automation");
  console.log("   □ Fund upkeep with LINK tokens");
  console.log("   □ Test contract creation and premium payment");
  console.log("   □ Verify automation triggers after 24 hours");
  console.log("   □ Monitor gas usage and optimize if needed");
  console.log("   □ Set up monitoring/alerts for contract health");

  console.log("\n🛠️  Management Functions:");
  console.log(`   • Toggle automation: provider.setAutomationEnabled(bool)`);
  console.log(`   • Change interval: provider.setUpkeepInterval(seconds)`);
  console.log(`   • Manual update: provider.manualWeatherUpdate(addresses[])`);
  console.log(`   • View active contracts: provider.getActiveContracts(start, limit)`);

  console.log("\n📈 Monitoring & Analytics:");
  console.log("   • Monitor AutomationUpkeepPerformed events");
  console.log("   • Track gas usage per upkeep");
  console.log("   • Monitor contract activation/deactivation");
  console.log("   • Set up alerts for failed weather checks");

  console.log("\n💡 Gas Optimization Tips:");
  console.log("   • Batch size automatically limited to 10 contracts");
  console.log("   • Failed contracts skipped, don't block others");
  console.log("   • Upkeep only runs when contracts need updates");
  console.log("   • Consider increasing upkeep interval if gas costs are high");

  // Example usage
  console.log("\n" + "=".repeat(60));
  console.log("📖 EXAMPLE USAGE");
  console.log("=".repeat(60));

  console.log(`
// JavaScript example for creating automated insurance contracts:

const provider = await AutomatedInsuranceProvider.at("${provider.address}");

// 1. Create insurance contract
const tx = await provider.newContract(
  clientAddress,
  7 * 24 * 60 * 60, // 7 days
  100 * 10**8,     // 100 USD premium
  1000 * 10**8,    // 1000 USD payout
  "London,UK",     // Location
  "0x0000000000000000000000000000000000000000", // ETH payment
  { value: web3.utils.toWei("1", "ether") }
);

// 2. Client pays premium (activates automation)
await provider.payPremium(contractAddress, {
  from: clientAddress,
  value: premiumInETH
});

// 3. Automation begins - no manual intervention needed!
// Weather checks happen automatically every 24 hours

// 4. Monitor automation status
const activeContracts = await provider.getActiveContractsCount();
const lastUpkeep = await provider.lastUpkeepTimestamp();
  `);

  console.log("\n🎯 Next Steps:");
  console.log("   1. Complete Chainlink Automation registration");
  console.log("   2. Test the system with small contracts first");
  console.log("   3. Monitor performance and gas usage");
  console.log("   4. Scale up to production workloads");

  console.log("\n" + "=".repeat(60));
  console.log("✅ DEPLOYMENT SUCCESSFUL - SYSTEM READY FOR AUTOMATION!");
  console.log("=".repeat(60));
};