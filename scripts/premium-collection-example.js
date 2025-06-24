/**
 * Premium Collection System Example
 * 
 * This script demonstrates the complete lifecycle of the premium collection system:
 * 1. Create insurance contract
 * 2. Client pays premium
 * 3. Contract activates
 * 4. Contract execution (weather monitoring)
 * 5. Contract completion and premium claiming
 */

const InsuranceProvider = artifacts.require("InsuranceProvider");
const InsuranceContract = artifacts.require("InsuranceContract");

module.exports = async function(callback) {
  try {
    console.log("🚀 Premium Collection System Demo\n");

    // Get contract instance
    const provider = await InsuranceProvider.deployed();
    const accounts = await web3.eth.getAccounts();
    const [owner, client] = accounts;

    console.log("📋 Setup Information:");
    console.log(`Provider Contract: ${provider.address}`);
    console.log(`Owner: ${owner}`);
    console.log(`Client: ${client}`);
    console.log(`Client ETH Balance: ${web3.utils.fromWei(await web3.eth.getBalance(client))} ETH\n`);

    // Contract parameters
    const duration = 7 * 24 * 60 * 60; // 7 days
    const premiumUSD = 100 * 10**8; // 100 USD with 8 decimals
    const payoutUSD = 1000 * 10**8; // 1000 USD with 8 decimals
    const location = "London,UK";
    const paymentToken = "0x0000000000000000000000000000000000000000"; // ETH

    console.log("📝 Contract Parameters:");
    console.log(`Duration: ${duration / (24 * 60 * 60)} days`);
    console.log(`Premium: ${premiumUSD / 10**8} USD`);
    console.log(`Payout: ${payoutUSD / 10**8} USD`);
    console.log(`Location: ${location}`);
    console.log(`Payment Token: ETH\n`);

    // Step 1: Create insurance contract
    console.log("🏗️  Step 1: Creating Insurance Contract...");
    
    const fundingAmount = web3.utils.toWei("1", "ether"); // Fund contract with 1 ETH for payouts
    const createTx = await provider.newContract(
      client,
      duration,
      premiumUSD,
      payoutUSD,
      location,
      paymentToken,
      { from: owner, value: fundingAmount }
    );

    // Get contract address from events
    const contractCreatedEvent = createTx.logs.find(log => log.event === "ContractCreated");
    const contractAddress = contractCreatedEvent.args.insuranceContract;
    
    console.log(`✅ Contract created at: ${contractAddress}`);

    // Get the insurance contract instance
    const insurance = await InsuranceContract.at(contractAddress);

    // Check initial contract state
    const isActiveInitial = await insurance.isActive();
    console.log(`🔴 Contract initially active: ${isActiveInitial}`);

    // Check premium information
    const premiumInfo = await provider.getPremiumInfo(contractAddress);
    console.log(`💰 Premium amount: ${premiumInfo.amount / 10**8} USD`);
    console.log(`🪙  Payment token: ${premiumInfo.token === '0x0000000000000000000000000000000000000000' ? 'ETH' : premiumInfo.token}`);
    console.log(`📊 Premium paid: ${premiumInfo.paid}\n`);

    // Step 2: Client pays premium
    console.log("💳 Step 2: Client Paying Premium...");
    
    // Calculate premium amount in ETH (assuming ETH price ~$2000)
    const ethPrice = await provider.getLatestPrice();
    const premiumETH = (premiumUSD * web3.utils.toWei("1", "ether")) / ethPrice;
    
    console.log(`🏷️  ETH Price: $${ethPrice / 10**8}`);
    console.log(`💸 Premium in ETH: ${web3.utils.fromWei(premiumETH.toString())} ETH`);

    // Client pays premium
    const paymentTx = await provider.payPremium(contractAddress, {
      from: client,
      value: premiumETH.toString()
    });

    console.log(`✅ Premium payment successful!`);
    console.log(`📄 Transaction hash: ${paymentTx.tx}`);

    // Check premium payment event
    const premiumPaidEvent = paymentTx.logs.find(log => log.event === "PremiumPaid");
    if (premiumPaidEvent) {
      console.log(`🎉 PremiumPaid event emitted for ${premiumPaidEvent.args.amount / 10**8} USD`);
    }

    // Step 3: Verify contract activation
    console.log("\n🔧 Step 3: Verifying Contract Activation...");
    
    const isActiveAfterPayment = await insurance.isActive();
    const updatedPremiumInfo = await provider.getPremiumInfo(contractAddress);
    
    console.log(`🟢 Contract now active: ${isActiveAfterPayment}`);
    console.log(`✅ Premium marked as paid: ${updatedPremiumInfo.paid}`);
    console.log(`⏰ Payment timestamp: ${new Date(updatedPremiumInfo.paidAt * 1000).toISOString()}\n`);

    // Step 4: Contract execution simulation
    console.log("⚡ Step 4: Contract Execution Phase...");
    console.log("🌦️  In production, this contract would:");
    console.log("   • Monitor weather data daily via Chainlink oracles");
    console.log("   • Track consecutive days without rainfall");
    console.log("   • Automatically trigger payouts after 3+ drought days");
    console.log("   • Update rainfall data from multiple API sources\n");

    // Display contract status
    console.log("📊 Current Contract Status:");
    console.log(`   • Client: ${await insurance.client()}`);
    console.log(`   • Duration: ${await insurance.getDuration()} seconds`);
    console.log(`   • Start Date: ${new Date((await insurance.getContractStartDate()) * 1000).toISOString()}`);
    console.log(`   • Premium: ${(await insurance.getPremium()) / 10**8} USD`);
    console.log(`   • Payout Value: ${(await insurance.getPayoutValue()) / 10**8} USD`);
    console.log(`   • Location: ${await insurance.getLocation()}`);
    console.log(`   • Current Rainfall: ${await insurance.getCurrentRainfall()} mm`);
    console.log(`   • Days Without Rain: ${await insurance.getDaysWithoutRain()}`);

    // Step 5: Demonstrate premium claiming (simulation)
    console.log("\n🏆 Step 5: Premium Claiming Process...");
    console.log("💡 After contract completion, the insurer can:");
    console.log("   • Call claimPremium() to collect the client's premium payment");
    console.log("   • This happens when contracts expire without payout");
    console.log("   • Premiums are held in escrow until contracts complete");
    
    // Get current balances for demonstration
    const providerBalance = await web3.eth.getBalance(provider.address);
    const insuranceBalance = await web3.eth.getBalance(contractAddress);
    
    console.log(`\n💰 Current Balances:`);
    console.log(`   • Provider Contract: ${web3.utils.fromWei(providerBalance)} ETH`);
    console.log(`   • Insurance Contract: ${web3.utils.fromWei(insuranceBalance)} ETH`);

    // Example of additional functionality
    console.log("\n🔄 Additional Available Functions:");
    console.log("   • provider.isPremiumPaid(contractAddress) - Check if premium is paid");
    console.log("   • provider.refundPremium(contractAddress) - Refund unpaid premiums");
    console.log("   • provider.updateContract(contractAddress) - Trigger weather data update");
    console.log("   • insurance.getCurrentRainfall() - Get latest rainfall data");

    // Display key features
    console.log("\n✨ Key Premium Collection Features:");
    console.log("   ✅ Escrow-based premium collection");
    console.log("   ✅ 24-hour grace period for premium payment");
    console.log("   ✅ Multi-token support (ETH, USDC, DAI, USDT)");
    console.log("   ✅ Automatic contract activation after payment");
    console.log("   ✅ Premium refunds for inactive contracts");
    console.log("   ✅ Secure premium claiming for insurers");
    console.log("   ✅ Reentrancy protection on all transfers");
    console.log("   ✅ Event emission for all premium operations");

    console.log("\n🎯 Demo completed successfully!");
    console.log("The premium collection system is now fully operational.");

  } catch (error) {
    console.error("❌ Error during demo:", error);
  }

  callback();
};