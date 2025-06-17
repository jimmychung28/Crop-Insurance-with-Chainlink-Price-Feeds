/**
 * Multi-Token Usage Example Script
 * 
 * This script demonstrates how to use the multi-token functionality
 * of the crop insurance system.
 */

const InsuranceProvider = artifacts.require('InsuranceProvider');
const MockERC20 = artifacts.require('MockERC20');

module.exports = async function(callback) {
  try {
    console.log('🌱 Multi-Token Crop Insurance Example\n');
    
    const accounts = await web3.eth.getAccounts();
    const [owner, client] = accounts;
    
    console.log('👤 Accounts:');
    console.log(`   Owner: ${owner}`);
    console.log(`   Client: ${client}\n`);
    
    // Get deployed InsuranceProvider contract
    const provider = await InsuranceProvider.deployed();
    console.log(`📋 InsuranceProvider: ${provider.address}\n`);
    
    // === 1. Check Supported Tokens ===
    console.log('💰 Checking supported tokens...');
    
    const ethSupported = await provider.supportedTokens('0x0000000000000000000000000000000000000000');
    console.log(`   ETH supported: ${ethSupported}`);
    
    const usdcAddress = await provider.USDC();
    const daiAddress = await provider.DAI();
    
    if (usdcAddress !== '0x0000000000000000000000000000000000000000') {
      const usdcSupported = await provider.supportedTokens(usdcAddress);
      console.log(`   USDC (${usdcAddress}): ${usdcSupported}`);
    }
    
    if (daiAddress !== '0x0000000000000000000000000000000000000000') {
      const daiSupported = await provider.supportedTokens(daiAddress);
      console.log(`   DAI (${daiAddress}): ${daiSupported}`);
    }
    
    console.log('');
    
    // === 2. Deploy Mock Tokens for Demo ===
    console.log('🪙 Deploying mock tokens for demonstration...');
    
    const mockUSDC = await MockERC20.new('USD Coin', 'USDC', 6, { from: owner });
    const mockDAI = await MockERC20.new('Dai Stablecoin', 'DAI', 18, { from: owner });
    
    console.log(`   Mock USDC: ${mockUSDC.address}`);
    console.log(`   Mock DAI: ${mockDAI.address}\n`);
    
    // Mint tokens for testing
    await mockUSDC.mint(owner, web3.utils.toWei('10000', 'mwei')); // 10,000 USDC (6 decimals)
    await mockDAI.mint(owner, web3.utils.toWei('10000', 'ether')); // 10,000 DAI (18 decimals)
    
    console.log('💎 Minted 10,000 tokens each for testing\n');
    
    // === 3. Add Mock Tokens to Provider ===
    console.log('➕ Adding mock tokens to provider...');
    
    const mockPriceFeed = '0x1111111111111111111111111111111111111111';
    
    await provider.addSupportedToken(mockUSDC.address, mockPriceFeed, { from: owner });
    await provider.addSupportedToken(mockDAI.address, mockPriceFeed, { from: owner });
    
    console.log('   ✅ Mock tokens added successfully\n');
    
    // === 4. Create Insurance with ETH ===
    console.log('🔷 Creating insurance contract with ETH...');
    
    const contractParams = {
      duration: 86400 * 30, // 30 days
      premium: 100, // $100 premium
      payoutValue: 1000, // $1000 payout
      location: 'Iowa, USA'
    };
    
    try {
      const ethTx = await provider.newContract(
        client,
        contractParams.duration,
        contractParams.premium,
        contractParams.payoutValue,
        contractParams.location,
        '0x0000000000000000000000000000000000000000', // ETH
        { 
          from: owner, 
          value: web3.utils.toWei('0.5', 'ether') // Send some ETH for contract funding
        }
      );
      
      const ethContractAddress = ethTx.logs.find(log => log.event === 'ContractCreated').args.insuranceContract;
      console.log(`   ✅ ETH Contract created: ${ethContractAddress}\n`);
    } catch (error) {
      console.log(`   ❌ ETH Contract creation failed: ${error.message}\n`);
    }
    
    // === 5. Create Insurance with USDC ===
    console.log('🔷 Creating insurance contract with USDC...');
    
    try {
      // Approve USDC for contract creation
      await mockUSDC.approve(provider.address, web3.utils.toWei('1000', 'mwei'), { from: owner });
      
      const usdcTx = await provider.newContract(
        client,
        contractParams.duration,
        contractParams.premium,
        contractParams.payoutValue,
        contractParams.location,
        mockUSDC.address,
        { from: owner }
      );
      
      const usdcContractAddress = usdcTx.logs.find(log => log.event === 'ContractCreated').args.insuranceContract;
      console.log(`   ✅ USDC Contract created: ${usdcContractAddress}\n`);
    } catch (error) {
      console.log(`   ❌ USDC Contract creation failed: ${error.message}\n`);
    }
    
    // === 6. Create Insurance with DAI ===
    console.log('🔷 Creating insurance contract with DAI...');
    
    try {
      // Approve DAI for contract creation
      await mockDAI.approve(provider.address, web3.utils.toWei('1000', 'ether'), { from: owner });
      
      const daiTx = await provider.newContract(
        client,
        contractParams.duration,
        contractParams.premium,
        contractParams.payoutValue,
        contractParams.location,
        mockDAI.address,
        { from: owner }
      );
      
      const daiContractAddress = daiTx.logs.find(log => log.event === 'ContractCreated').args.insuranceContract;
      console.log(`   ✅ DAI Contract created: ${daiContractAddress}\n`);
    } catch (error) {
      console.log(`   ❌ DAI Contract creation failed: ${error.message}\n`);
    }
    
    // === 7. Display Token Balances ===
    console.log('💰 Final token balances:');
    
    const ethBalance = await web3.eth.getBalance(owner);
    const usdcBalance = await mockUSDC.balanceOf(owner);
    const daiBalance = await mockDAI.balanceOf(owner);
    
    console.log(`   ETH: ${web3.utils.fromWei(ethBalance, 'ether')} ETH`);
    console.log(`   USDC: ${web3.utils.fromWei(usdcBalance, 'mwei')} USDC`);
    console.log(`   DAI: ${web3.utils.fromWei(daiBalance, 'ether')} DAI\n`);
    
    // === 8. Price Calculation Examples ===
    console.log('📊 Price calculation examples:');
    
    try {
      const usdAmount = 1000; // $1000
      
      // Note: These will fail without proper price feeds, but show the interface
      console.log(`   Calculating token amounts for $${usdAmount}:`);
      
      try {
        const usdcAmount = await provider.getTokenAmountForUSD(mockUSDC.address, usdAmount);
        console.log(`   USDC needed: ${usdcAmount}`);
      } catch (error) {
        console.log(`   USDC calculation: ${error.message.split('revert ')[1] || error.message}`);
      }
      
      try {
        const daiAmount = await provider.getTokenAmountForUSD(mockDAI.address, usdAmount);
        console.log(`   DAI needed: ${daiAmount}`);
      } catch (error) {
        console.log(`   DAI calculation: ${error.message.split('revert ')[1] || error.message}`);
      }
      
    } catch (error) {
      console.log(`   Price calculation failed: ${error.message}`);
    }
    
    console.log('\n✅ Multi-token example completed successfully!');
    console.log('\nℹ️  Note: Price calculations require proper Chainlink price feeds');
    console.log('   In production, configure real price feed addresses for accurate conversions.');
    
    callback();
  } catch (error) {
    console.error('❌ Example failed:', error);
    callback(error);
  }
};