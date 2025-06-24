/**
 * Manual Weather Update Script
 * 
 * Emergency override script for manually triggering weather updates
 * when automation is disabled or for testing purposes.
 */

const AutomatedInsuranceProvider = artifacts.require("AutomatedInsuranceProvider");
const AutomatedInsuranceContract = artifacts.require("AutomatedInsuranceContract");

module.exports = async function(callback) {
  try {
    console.log("🌦️  Manual Weather Update Tool\n");

    const provider = await AutomatedInsuranceProvider.deployed();
    const accounts = await web3.eth.getAccounts();
    const [owner] = accounts;

    console.log("📋 System Information:");
    console.log(`Provider Contract: ${provider.address}`);
    console.log(`Owner: ${owner}`);

    // Get active contracts
    const activeCount = await provider.getActiveContractsCount();
    console.log(`Active Contracts: ${activeCount}\n`);

    if (activeCount == 0) {
      console.log("⚠️  No active contracts to update.");
      console.log("Create some contracts first using the automation setup script.");
      callback();
      return;
    }

    // Get all active contracts
    const batchSize = Math.min(50, parseInt(activeCount)); // Process up to 50 contracts
    const activeContracts = await provider.getActiveContracts(0, batchSize);

    console.log("📊 Analyzing active contracts...\n");

    const contractsNeedingUpdate = [];
    const contractsNotReady = [];

    // Check which contracts need updates
    for (let i = 0; i < activeContracts.length; i++) {
      const contractAddr = activeContracts[i];
      
      try {
        const insurance = await AutomatedInsuranceContract.at(contractAddr);
        const needsUpdate = await insurance.needsWeatherUpdate();
        const isActive = await insurance.isActive();
        const location = await insurance.getLocation();
        const client = await insurance.client();
        const daysWithoutRain = await insurance.getDaysWithoutRain();
        const currentRainfall = await insurance.getCurrentRainfall();

        console.log(`${i + 1}. ${contractAddr}`);
        console.log(`   Location: ${location}`);
        console.log(`   Client: ${client.substring(0, 10)}...`);
        console.log(`   Active: ${isActive}`);
        console.log(`   Needs Update: ${needsUpdate}`);
        console.log(`   Days Without Rain: ${daysWithoutRain}`);
        console.log(`   Current Rainfall: ${currentRainfall} mm`);

        if (isActive && needsUpdate) {
          contractsNeedingUpdate.push({
            address: contractAddr,
            location: location,
            client: client,
            daysWithoutRain: daysWithoutRain
          });
          console.log("   ✅ Ready for update");
        } else if (!isActive) {
          contractsNotReady.push({
            address: contractAddr,
            reason: "Contract not active"
          });
          console.log("   ❌ Not active");
        } else if (!needsUpdate) {
          contractsNotReady.push({
            address: contractAddr,
            reason: "Too soon for update"
          });
          console.log("   ⏰ Too soon for update");
        }
        
        console.log(""); // Empty line for readability
        
      } catch (error) {
        console.log(`   ❌ Error: ${error.message}\n`);
        contractsNotReady.push({
          address: contractAddr,
          reason: `Error: ${error.message}`
        });
      }
    }

    console.log("📈 Update Summary:");
    console.log(`Contracts ready for update: ${contractsNeedingUpdate.length}`);
    console.log(`Contracts not ready: ${contractsNotReady.length}`);

    if (contractsNeedingUpdate.length === 0) {
      console.log("\n⚠️  No contracts need weather updates at this time.");
      console.log("This could mean:");
      console.log("• All contracts were recently updated (< 24 hours ago)");
      console.log("• No contracts are currently active");
      console.log("• All contracts have already completed or paid out");
      
      callback();
      return;
    }

    // Show contracts that will be updated
    console.log("\n🎯 Contracts to be updated:");
    contractsNeedingUpdate.forEach((contract, i) => {
      console.log(`${i + 1}. ${contract.address}`);
      console.log(`   Location: ${contract.location}`);
      console.log(`   Days without rain: ${contract.daysWithoutRain}`);
      
      if (contract.daysWithoutRain >= 2) {
        console.log(`   ⚠️  DROUGHT RISK: ${contract.daysWithoutRain}/3 days`);
      }
    });

    // Perform manual weather updates
    console.log("\n🚀 Starting manual weather updates...\n");

    const contractAddresses = contractsNeedingUpdate.map(c => c.address);
    
    // Split into batches of 10 for gas efficiency
    const batchCount = Math.ceil(contractAddresses.length / 10);
    
    for (let batch = 0; batch < batchCount; batch++) {
      const batchStart = batch * 10;
      const batchEnd = Math.min(batchStart + 10, contractAddresses.length);
      const batchAddresses = contractAddresses.slice(batchStart, batchEnd);
      
      console.log(`Processing batch ${batch + 1}/${batchCount} (${batchAddresses.length} contracts)...`);
      
      try {
        // Estimate gas for the batch
        const gasEstimate = await provider.manualWeatherUpdate.estimateGas(batchAddresses, { from: owner });
        console.log(`Gas estimate: ${gasEstimate.toLocaleString()}`);
        
        // Execute the batch update
        const startTime = Date.now();
        const tx = await provider.manualWeatherUpdate(batchAddresses, { from: owner });
        const endTime = Date.now();
        
        console.log(`✅ Batch ${batch + 1} completed`);
        console.log(`   Transaction: ${tx.tx}`);
        console.log(`   Gas used: ${tx.receipt.gasUsed.toLocaleString()}`);
        console.log(`   Time taken: ${endTime - startTime}ms`);
        console.log("");
        
        // Brief pause between batches to avoid overwhelming the network
        if (batch < batchCount - 1) {
          console.log("⏳ Waiting 5 seconds before next batch...\n");
          await new Promise(resolve => setTimeout(resolve, 5000));
        }
        
      } catch (error) {
        console.log(`❌ Batch ${batch + 1} failed: ${error.message}\n`);
        
        // Try individual updates for this batch
        console.log("🔄 Attempting individual updates for failed batch...");
        
        for (const contractAddr of batchAddresses) {
          try {
            const insurance = await AutomatedInsuranceContract.at(contractAddr);
            const individualTx = await insurance.performAutomatedWeatherCheck({ from: owner });
            console.log(`✅ Individual update: ${contractAddr}`);
          } catch (individualError) {
            console.log(`❌ Individual update failed: ${contractAddr} - ${individualError.message}`);
          }
        }
      }
    }

    // Post-update analysis
    console.log("📊 Post-Update Analysis:\n");
    
    let updatedCount = 0;
    let payoutTriggered = 0;
    let contractsEnded = 0;
    
    for (const contract of contractsNeedingUpdate) {
      try {
        const insurance = await AutomatedInsuranceContract.at(contract.address);
        const isActive = await insurance.isActive();
        const currentRainfall = await insurance.getCurrentRainfall();
        const daysWithoutRain = await insurance.getDaysWithoutRain();
        const contractPaid = await insurance.contractPaid();
        
        console.log(`${contract.address}:`);
        console.log(`   Location: ${contract.location}`);
        console.log(`   Still Active: ${isActive}`);
        console.log(`   Current Rainfall: ${currentRainfall} mm`);
        console.log(`   Days Without Rain: ${daysWithoutRain}`);
        
        if (!isActive && contractPaid) {
          console.log(`   🎯 PAYOUT TRIGGERED!`);
          payoutTriggered++;
        } else if (!isActive && !contractPaid) {
          console.log(`   📅 Contract ended normally`);
          contractsEnded++;
        } else if (daysWithoutRain > contract.daysWithoutRain) {
          console.log(`   📈 Drought counter increased`);
        } else if (currentRainfall > 0) {
          console.log(`   🌧️  Rain detected - counter reset`);
        }
        
        updatedCount++;
        console.log("");
        
      } catch (error) {
        console.log(`   ❌ Error checking post-update status: ${error.message}\n`);
      }
    }

    // Final summary
    console.log("" + "=".repeat(50));
    console.log("📋 MANUAL UPDATE SUMMARY");
    console.log("=".repeat(50));
    console.log(`Total contracts processed: ${contractsNeedingUpdate.length}`);
    console.log(`Successfully updated: ${updatedCount}`);
    console.log(`Payouts triggered: ${payoutTriggered}`);
    console.log(`Contracts ended: ${contractsEnded}`);
    console.log(`Still monitoring: ${updatedCount - payoutTriggered - contractsEnded}`);

    if (payoutTriggered > 0) {
      console.log(`\n🎉 ${payoutTriggered} contract(s) triggered payouts due to drought conditions!`);
    }

    // Recommendations
    console.log("\n💡 Recommendations:");
    
    if (contractsNotReady.length > 0) {
      console.log(`• ${contractsNotReady.length} contracts were not ready for updates`);
      console.log("  Consider checking these again in a few hours");
    }
    
    if (payoutTriggered > 0) {
      console.log("• Monitor payout transactions to ensure they completed successfully");
    }
    
    console.log("• Set up Chainlink Automation to avoid manual interventions");
    console.log("• Monitor gas costs and optimize batch sizes if needed");
    
    const finalActiveCount = await provider.getActiveContractsCount();
    console.log(`\nActive contracts remaining: ${finalActiveCount}`);

    console.log("\n✅ Manual weather update completed!");

  } catch (error) {
    console.error("❌ Error during manual weather update:", error);
  }

  callback();
};