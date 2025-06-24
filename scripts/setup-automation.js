/**
 * Chainlink Automation Setup Script
 * 
 * This script helps set up and test the automated weather monitoring system.
 * It provides utilities for:
 * - Testing automation interface functions
 * - Creating test contracts for automation
 * - Monitoring automation performance
 * - Emergency manual overrides
 */

const AutomatedInsuranceProvider = artifacts.require("AutomatedInsuranceProvider");
const AutomatedInsuranceContract = artifacts.require("AutomatedInsuranceContract");

module.exports = async function(callback) {
  try {
    console.log("🔧 Chainlink Automation Setup & Testing Tool\n");

    const provider = await AutomatedInsuranceProvider.deployed();
    const accounts = await web3.eth.getAccounts();
    const [owner, client1, client2] = accounts;

    console.log("📋 System Information:");
    console.log(`Provider Contract: ${provider.address}`);
    console.log(`Owner: ${owner}`);
    console.log(`Network: ${await web3.eth.net.getNetworkType()}`);

    // Check current automation status
    const automationEnabled = await provider.automationEnabled();
    const upkeepInterval = await provider.upkeepInterval();
    const lastUpkeep = await provider.lastUpkeepTimestamp();
    const activeContractsCount = await provider.getActiveContractsCount();

    console.log("\n⚙️  Current Automation Status:");
    console.log(`Automation Enabled: ${automationEnabled}`);
    console.log(`Upkeep Interval: ${upkeepInterval} seconds (${(upkeepInterval/86400).toFixed(1)} days)`);
    console.log(`Last Upkeep: ${new Date(lastUpkeep * 1000).toISOString()}`);
    console.log(`Active Contracts: ${activeContractsCount}`);

    // Test automation interface
    console.log("\n🧪 Testing Automation Interface...");
    
    const checkData = "0x";
    const checkResult = await provider.checkUpkeep(checkData);
    
    console.log(`checkUpkeep() result:`);
    console.log(`  • Upkeep Needed: ${checkResult.upkeepNeeded}`);
    console.log(`  • Perform Data Length: ${checkResult.performData.length} bytes`);
    
    if (checkResult.upkeepNeeded) {
      console.log("✅ System ready for automation upkeep");
      
      // Decode performData to see which contracts would be processed
      try {
        const contractBatch = web3.eth.abi.decodeParameter('address[]', checkResult.performData);
        console.log(`  • Contracts to process: ${contractBatch.length}`);
        contractBatch.forEach((addr, i) => {
          console.log(`    ${i + 1}. ${addr}`);
        });
      } catch (error) {
        console.log("  • No contracts to process");
      }
    } else {
      console.log("ℹ️  No upkeep needed at this time");
      
      const timeSinceLastUpkeep = Date.now()/1000 - lastUpkeep;
      const timeUntilNext = upkeepInterval - timeSinceLastUpkeep;
      
      if (timeUntilNext > 0) {
        console.log(`  • Next upkeep in: ${(timeUntilNext/3600).toFixed(1)} hours`);
      }
      
      if (activeContractsCount == 0) {
        console.log("  • No active contracts to monitor");
      }
    }

    // Create test contracts for automation if none exist
    if (activeContractsCount == 0) {
      console.log("\n🏗️  Creating Test Contracts for Automation...");
      
      const duration = 7 * 24 * 60 * 60; // 7 days
      const premiumUSD = 50 * 10**8; // 50 USD
      const payoutUSD = 500 * 10**8; // 500 USD
      const fundingAmount = web3.utils.toWei("0.5", "ether");
      
      // Create 2 test contracts
      const locations = ["London,UK", "Paris,FR"];
      const clients = [client1, client2];
      
      for (let i = 0; i < 2; i++) {
        console.log(`\nCreating contract ${i + 1}...`);
        
        const tx = await provider.newContract(
          clients[i],
          duration,
          premiumUSD,
          payoutUSD,
          locations[i],
          "0x0000000000000000000000000000000000000000", // ETH
          { from: owner, value: fundingAmount }
        );
        
        const contractAddress = tx.logs.find(log => log.event === "ContractCreated").args.insuranceContract;
        console.log(`✅ Contract created: ${contractAddress}`);
        
        // Pay premium to activate contract
        const premiumETH = web3.utils.toWei("0.025", "ether"); // ~$50 at $2000/ETH
        
        try {
          await provider.payPremium(contractAddress, {
            from: clients[i],
            value: premiumETH
          });
          console.log(`✅ Premium paid by ${clients[i]}`);
          console.log(`📍 Location: ${locations[i]}`);
        } catch (error) {
          console.log(`❌ Failed to pay premium: ${error.message}`);
        }
      }
      
      // Check updated status
      const newActiveCount = await provider.getActiveContractsCount();
      console.log(`\n✅ Active contracts now: ${newActiveCount}`);
    }

    // Show active contracts
    if (activeContractsCount > 0) {
      console.log("\n📊 Active Contracts:");
      
      const batchSize = Math.min(10, parseInt(activeContractsCount));
      const activeContracts = await provider.getActiveContracts(0, batchSize);
      
      for (let i = 0; i < activeContracts.length; i++) {
        const contractAddr = activeContracts[i];
        const insurance = await AutomatedInsuranceContract.at(contractAddr);
        
        try {
          const location = await insurance.getLocation();
          const client = await insurance.client();
          const isActive = await insurance.isActive();
          const needsUpdate = await insurance.needsWeatherUpdate();
          const currentRainfall = await insurance.getCurrentRainfall();
          const daysWithoutRain = await insurance.getDaysWithoutRain();
          
          console.log(`\n${i + 1}. Contract: ${contractAddr}`);
          console.log(`   Client: ${client}`);
          console.log(`   Location: ${location}`);
          console.log(`   Active: ${isActive}`);
          console.log(`   Needs Update: ${needsUpdate}`);
          console.log(`   Current Rainfall: ${currentRainfall} mm`);
          console.log(`   Days Without Rain: ${daysWithoutRain}`);
        } catch (error) {
          console.log(`   ❌ Error reading contract data: ${error.message}`);
        }
      }
    }

    // Automation Performance Analysis
    console.log("\n📈 Automation Performance Analysis:");
    
    // Estimate gas costs
    if (checkResult.upkeepNeeded) {
      try {
        const gasEstimate = await provider.performUpkeep.estimateGas(checkResult.performData);
        const gasPrice = await web3.eth.getGasPrice();
        const estimatedCost = gasEstimate * gasPrice;
        
        console.log(`Gas Estimate: ${gasEstimate.toLocaleString()} gas`);
        console.log(`Estimated Cost: ${web3.utils.fromWei(estimatedCost.toString())} ETH`);
        
        // Calculate cost per contract
        try {
          const contractBatch = web3.eth.abi.decodeParameter('address[]', checkResult.performData);
          if (contractBatch.length > 0) {
            const costPerContract = estimatedCost / contractBatch.length;
            console.log(`Cost per Contract: ${web3.utils.fromWei(costPerContract.toString())} ETH`);
          }
        } catch (e) {
          console.log("Could not decode contract batch for cost analysis");
        }
      } catch (error) {
        console.log(`Gas estimation failed: ${error.message}`);
      }
    }

    // Manual testing options
    console.log("\n🛠️  Manual Testing Options:");
    console.log("1. Test individual contract weather check:");
    console.log("   node -e 'const contract = await AutomatedInsuranceContract.at(\"CONTRACT_ADDRESS\"); await contract.performAutomatedWeatherCheck({from: \"OWNER_ADDRESS\"})'");
    
    console.log("\n2. Perform manual batch update:");
    console.log("   npx truffle exec scripts/manual-weather-update.js --network NETWORK");
    
    console.log("\n3. Toggle automation:");
    console.log("   provider.setAutomationEnabled(false) // Disable");
    console.log("   provider.setAutomationEnabled(true)  // Enable");

    // Chainlink Automation Registration Reminder
    console.log("\n" + "=".repeat(60));
    console.log("🔗 CHAINLINK AUTOMATION REGISTRATION");
    console.log("=".repeat(60));
    
    console.log(`
To complete automation setup:

1. Visit Chainlink Automation: https://automation.chain.link/
2. Register new upkeep with contract: ${provider.address}
3. Fund with LINK tokens (5-20 LINK recommended)
4. Set gas limit: 2,000,000
5. Monitor performance and adjust as needed

Registration Parameters:
• Contract Address: ${provider.address}
• Trigger Type: Custom Logic
• Gas Limit: 2,000,000
• Starting Balance: 10 LINK (testnet) / 20 LINK (mainnet)

After registration, automation will:
• Check weather every ${upkeepInterval/3600} hours
• Process up to 10 contracts per upkeep
• Automatically handle payouts when drought detected
• Manage contract lifecycle without manual intervention
    `);

    // Health check
    console.log("\n🏥 System Health Check:");
    
    const checks = [];
    
    // Check 1: Automation enabled
    checks.push({
      name: "Automation Enabled",
      status: automationEnabled,
      message: automationEnabled ? "✅ Enabled" : "❌ Disabled"
    });
    
    // Check 2: Active contracts
    checks.push({
      name: "Active Contracts",
      status: activeContractsCount > 0,
      message: activeContractsCount > 0 ? `✅ ${activeContractsCount} active` : "⚠️  No active contracts"
    });
    
    // Check 3: Recent upkeep
    const timeSinceUpkeep = Date.now()/1000 - lastUpkeep;
    const upkeepRecent = timeSinceUpkeep < (upkeepInterval * 2); // Within 2 intervals
    checks.push({
      name: "Recent Upkeep Activity",
      status: upkeepRecent,
      message: upkeepRecent ? `✅ Last upkeep ${(timeSinceUpkeep/3600).toFixed(1)}h ago` : `⚠️  Last upkeep ${(timeSinceUpkeep/3600).toFixed(1)}h ago`
    });
    
    // Check 4: Contract balance
    const providerBalance = await web3.eth.getBalance(provider.address);
    const hasBalance = parseFloat(web3.utils.fromWei(providerBalance)) > 0;
    checks.push({
      name: "Contract Balance",
      status: hasBalance,
      message: hasBalance ? `✅ ${web3.utils.fromWei(providerBalance)} ETH` : "⚠️  No ETH balance"
    });
    
    checks.forEach(check => {
      console.log(`${check.message}`);
    });
    
    const allHealthy = checks.every(check => check.status);
    console.log(`\nOverall System Health: ${allHealthy ? "✅ HEALTHY" : "⚠️  NEEDS ATTENTION"}`);

    console.log("\n✅ Automation setup check complete!");
    console.log("Monitor system performance and register with Chainlink Automation for full automation.");

  } catch (error) {
    console.error("❌ Error during automation setup:", error);
  }

  callback();
};