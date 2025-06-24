const AutomatedInsuranceProvider = artifacts.require("AutomatedInsuranceProvider");
const AutomatedInsuranceContract = artifacts.require("AutomatedInsuranceContract");
const MockERC20 = artifacts.require("MockERC20");
const { expectRevert, expectEvent, time } = require("@openzeppelin/test-helpers");
const { expect } = require("chai");
const BN = web3.utils.BN;

contract("Automated Weather Monitoring Tests", (accounts) => {
  const [owner, client1, client2, client3] = accounts;
  
  // Constants
  const DAY_IN_SECONDS = 86400;
  const DROUGHT_DAYS_THRESHOLD = 3;
  const UPKEEP_INTERVAL = DAY_IN_SECONDS;
  const MAX_CONTRACTS_PER_BATCH = 10;
  
  // Test parameters
  const duration = 7 * DAY_IN_SECONDS; // 7 days
  const premiumUSD = 100 * 10**8; // 100 USD
  const payoutUSD = 1000 * 10**8; // 1000 USD
  const location = "London,UK";
  
  let provider, mockUSDC;
  
  beforeEach(async () => {
    // Deploy automated insurance provider
    provider = await AutomatedInsuranceProvider.new(
      "test_world_weather_key",
      "test_open_weather_key", 
      "test_weatherbit_key",
      { from: owner }
    );
    
    // Deploy mock tokens
    mockUSDC = await MockERC20.new("USD Coin", "USDC", 6, { from: owner });
    await mockUSDC.mint(owner, web3.utils.toWei("10000", "mwei"), { from: owner });
    await mockUSDC.mint(client1, web3.utils.toWei("10000", "mwei"), { from: owner });
    
    // Add supported tokens
    const mockPriceFeed = "0x9326BFA02ADD2366b30bacB125260Af641031331";
    await provider.addSupportedToken(mockUSDC.address, mockPriceFeed, { from: owner });
  });
  
  describe("Chainlink Automation Interface", () => {
    let contractAddress1, contractAddress2, insurance1, insurance2;
    
    beforeEach(async () => {
      // Create multiple contracts for testing
      const fundingAmount = web3.utils.toWei("2", "ether");
      
      // Contract 1
      const tx1 = await provider.newContract(
        client1,
        duration,
        premiumUSD,
        payoutUSD,
        location,
        "0x0000000000000000000000000000000000000000", // ETH
        { from: owner, value: fundingAmount }
      );
      contractAddress1 = tx1.logs.find(log => log.event === "ContractCreated").args.insuranceContract;
      insurance1 = await AutomatedInsuranceContract.at(contractAddress1);
      
      // Contract 2
      const tx2 = await provider.newContract(
        client2,
        duration,
        premiumUSD,
        payoutUSD,
        "Paris,FR",
        "0x0000000000000000000000000000000000000000", // ETH
        { from: owner, value: fundingAmount }
      );
      contractAddress2 = tx2.logs.find(log => log.event === "ContractCreated").args.insuranceContract;
      insurance2 = await AutomatedInsuranceContract.at(contractAddress2);
      
      // Pay premiums to activate contracts
      const premiumETH = web3.utils.toWei("0.05", "ether");
      await provider.payPremium(contractAddress1, { from: client1, value: premiumETH });
      await provider.payPremium(contractAddress2, { from: client2, value: premiumETH });
    });
    
    it("should implement checkUpkeep correctly when no upkeep needed", async () => {
      // Check upkeep immediately after creation (should be false - not enough time passed)
      const checkData = "0x";
      const result = await provider.checkUpkeep(checkData);
      
      expect(result.upkeepNeeded).to.be.false;
      expect(result.performData).to.equal("0x");
    });
    
    it("should implement checkUpkeep correctly when upkeep is needed", async () => {
      // Advance time to trigger upkeep
      await time.increase(UPKEEP_INTERVAL + 1);
      
      const checkData = "0x";
      const result = await provider.checkUpkeep(checkData);
      
      expect(result.upkeepNeeded).to.be.true;
      expect(result.performData).to.not.equal("0x");
      
      // Decode perform data to verify it contains contract addresses
      const decodedData = web3.eth.abi.decodeParameter('address[]', result.performData);
      expect(decodedData).to.include(contractAddress1);
      expect(decodedData).to.include(contractAddress2);
    });
    
    it("should not need upkeep when automation is disabled", async () => {
      // Disable automation
      await provider.setAutomationEnabled(false, { from: owner });
      
      // Advance time
      await time.increase(UPKEEP_INTERVAL + 1);
      
      const checkData = "0x";
      const result = await provider.checkUpkeep(checkData);
      
      expect(result.upkeepNeeded).to.be.false;
    });
    
    it("should not need upkeep when no active contracts", async () => {
      // Deactivate all contracts
      await provider.deactivateContract(contractAddress1, { from: owner });
      await provider.deactivateContract(contractAddress2, { from: owner });
      
      // Advance time
      await time.increase(UPKEEP_INTERVAL + 1);
      
      const checkData = "0x";
      const result = await provider.checkUpkeep(checkData);
      
      expect(result.upkeepNeeded).to.be.false;
    });
  });
  
  describe("Automated Weather Monitoring", () => {
    let contractAddress, insurance;
    
    beforeEach(async () => {
      // Create and activate a contract
      const fundingAmount = web3.utils.toWei("1", "ether");
      const tx = await provider.newContract(
        client1,
        duration,
        premiumUSD,
        payoutUSD,
        location,
        "0x0000000000000000000000000000000000000000",
        { from: owner, value: fundingAmount }
      );
      
      contractAddress = tx.logs.find(log => log.event === "ContractCreated").args.insuranceContract;
      insurance = await AutomatedInsuranceContract.at(contractAddress);
      
      // Pay premium to activate
      const premiumETH = web3.utils.toWei("0.05", "ether");
      await provider.payPremium(contractAddress, { from: client1, value: premiumETH });
    });
    
    it("should perform automated upkeep and trigger weather checks", async () => {
      // Advance time to trigger upkeep
      await time.increase(UPKEEP_INTERVAL + 1);
      
      // Get upkeep data
      const checkResult = await provider.checkUpkeep("0x");
      expect(checkResult.upkeepNeeded).to.be.true;
      
      // Perform upkeep
      const tx = await provider.performUpkeep(checkResult.performData);
      
      // Check that upkeep was performed
      expectEvent(tx, "AutomationUpkeepPerformed", {
        contractsProcessed: "1"
      });
      
      // Verify last upkeep timestamp was updated
      const lastUpkeep = await provider.lastUpkeepTimestamp();
      const currentTime = await time.latest();
      expect(lastUpkeep).to.be.bignumber.closeTo(currentTime, new BN(10));
    });
    
    it("should handle individual contract weather checks", async () => {
      // Check that contract needs weather update initially
      const needsUpdate = await insurance.needsWeatherUpdate();
      expect(needsUpdate).to.be.true;
      
      // Perform weather check
      const tx = await insurance.performAutomatedWeatherCheck({ from: owner });
      
      // Verify event was emitted
      expectEvent(tx, "AutomatedWeatherCheckPerformed");
      
      // Check that contract no longer needs immediate update
      const stillNeedsUpdate = await insurance.needsWeatherUpdate();
      expect(stillNeedsUpdate).to.be.false;
    });
    
    it("should not allow weather check if insufficient time has passed", async () => {
      // Perform first weather check
      await insurance.performAutomatedWeatherCheck({ from: owner });
      
      // Try to perform another check immediately
      await expectRevert(
        insurance.performAutomatedWeatherCheck({ from: owner }),
        "Too soon for weather check"
      );
    });
    
    it("should automatically end contract when duration expires", async () => {
      // Advance time past contract duration
      await time.increase(duration + 1);
      
      // Perform weather check - should trigger contract end
      const tx = await insurance.performAutomatedWeatherCheck({ from: owner });
      
      // Check that contract is no longer active
      const isActive = await insurance.isActive();
      expect(isActive).to.be.false;
    });
  });
  
  describe("Batch Processing", () => {
    let contractAddresses = [];
    let insurances = [];
    
    beforeEach(async () => {
      const fundingAmount = web3.utils.toWei("1", "ether");
      const premiumETH = web3.utils.toWei("0.05", "ether");
      
      // Create 5 contracts for batch testing
      for (let i = 0; i < 5; i++) {
        const tx = await provider.newContract(
          client1,
          duration,
          premiumUSD,
          payoutUSD,
          `Location${i}`,
          "0x0000000000000000000000000000000000000000",
          { from: owner, value: fundingAmount }
        );
        
        const contractAddress = tx.logs.find(log => log.event === "ContractCreated").args.insuranceContract;
        contractAddresses.push(contractAddress);
        insurances.push(await AutomatedInsuranceContract.at(contractAddress));
        
        // Activate contract
        await provider.payPremium(contractAddress, { from: client1, value: premiumETH });
      }
    });
    
    it("should process multiple contracts in batch during upkeep", async () => {
      // Verify all contracts are active
      const activeCount = await provider.getActiveContractsCount();
      expect(activeCount).to.be.bignumber.equal(new BN(5));
      
      // Advance time to trigger upkeep
      await time.increase(UPKEEP_INTERVAL + 1);
      
      // Perform upkeep
      const checkResult = await provider.checkUpkeep("0x");
      const tx = await provider.performUpkeep(checkResult.performData);
      
      // Should process all 5 contracts
      expectEvent(tx, "AutomationUpkeepPerformed", {
        contractsProcessed: "5"
      });
    });
    
    it("should respect MAX_CONTRACTS_PER_BATCH limit", async () => {
      // Create more contracts than batch limit
      const fundingAmount = web3.utils.toWei("1", "ether");
      const premiumETH = web3.utils.toWei("0.05", "ether");
      
      // Create 15 total contracts (10 more than current 5)
      for (let i = 5; i < 15; i++) {
        const tx = await provider.newContract(
          client1,
          duration,
          premiumUSD,
          payoutUSD,
          `Location${i}`,
          "0x0000000000000000000000000000000000000000",
          { from: owner, value: fundingAmount }
        );
        
        const contractAddress = tx.logs.find(log => log.event === "ContractCreated").args.insuranceContract;
        await provider.payPremium(contractAddress, { from: client1, value: premiumETH });
      }
      
      // Should have 15 active contracts
      const activeCount = await provider.getActiveContractsCount();
      expect(activeCount).to.be.bignumber.equal(new BN(15));
      
      // Advance time and perform upkeep
      await time.increase(UPKEEP_INTERVAL + 1);
      const checkResult = await provider.checkUpkeep("0x");
      const tx = await provider.performUpkeep(checkResult.performData);
      
      // Should only process MAX_CONTRACTS_PER_BATCH (10) contracts
      expectEvent(tx, "AutomationUpkeepPerformed", {
        contractsProcessed: "10"
      });
    });
    
    it("should handle contract activation and deactivation", async () => {
      // Initial count
      expect(await provider.getActiveContractsCount()).to.be.bignumber.equal(new BN(5));
      
      // Deactivate one contract
      await provider.deactivateContract(contractAddresses[0], { from: owner });
      
      // Count should decrease
      expect(await provider.getActiveContractsCount()).to.be.bignumber.equal(new BN(4));
      
      // Get active contracts
      const activeContracts = await provider.getActiveContracts(0, 10);
      expect(activeContracts).to.not.include(contractAddresses[0]);
      expect(activeContracts.length).to.equal(4);
    });
  });
  
  describe("Gas Efficiency", () => {
    it("should measure gas costs for automation upkeep", async () => {
      // Create and activate contract
      const fundingAmount = web3.utils.toWei("1", "ether");
      const tx = await provider.newContract(
        client1,
        duration,
        premiumUSD,
        payoutUSD,
        location,
        "0x0000000000000000000000000000000000000000",
        { from: owner, value: fundingAmount }
      );
      
      const contractAddress = tx.logs.find(log => log.event === "ContractCreated").args.insuranceContract;
      const premiumETH = web3.utils.toWei("0.05", "ether");
      await provider.payPremium(contractAddress, { from: client1, value: premiumETH });
      
      // Advance time and perform upkeep
      await time.increase(UPKEEP_INTERVAL + 1);
      const checkResult = await provider.checkUpkeep("0x");
      
      // Measure gas for performUpkeep
      const gasEstimate = await provider.performUpkeep.estimateGas(checkResult.performData);
      console.log(`Gas estimate for single contract upkeep: ${gasEstimate}`);
      
      // Gas should be reasonable (less than 500k for single contract)
      expect(gasEstimate).to.be.lessThan(500000);
    });
    
    it("should measure gas efficiency for batch processing", async () => {
      const fundingAmount = web3.utils.toWei("1", "ether");
      const premiumETH = web3.utils.toWei("0.05", "ether");
      
      // Create 5 contracts
      for (let i = 0; i < 5; i++) {
        const tx = await provider.newContract(
          client1,
          duration,
          premiumUSD,
          payoutUSD,
          `Location${i}`,
          "0x0000000000000000000000000000000000000000",
          { from: owner, value: fundingAmount }
        );
        
        const contractAddress = tx.logs.find(log => log.event === "ContractCreated").args.insuranceContract;
        await provider.payPremium(contractAddress, { from: client1, value: premiumETH });
      }
      
      // Measure batch upkeep gas
      await time.increase(UPKEEP_INTERVAL + 1);
      const checkResult = await provider.checkUpkeep("0x");
      const gasEstimate = await provider.performUpkeep.estimateGas(checkResult.performData);
      
      console.log(`Gas estimate for 5 contract batch upkeep: ${gasEstimate}`);
      
      // Batch processing should be more efficient than 5x single contract
      const expectedIndividualGas = 500000 * 5; // 5 * single contract gas
      expect(gasEstimate).to.be.lessThan(expectedIndividualGas * 0.8); // At least 20% more efficient
    });
  });
  
  describe("Error Handling and Edge Cases", () => {
    let contractAddress, insurance;
    
    beforeEach(async () => {
      const fundingAmount = web3.utils.toWei("1", "ether");
      const tx = await provider.newContract(
        client1,
        duration,
        premiumUSD,
        payoutUSD,
        location,
        "0x0000000000000000000000000000000000000000",
        { from: owner, value: fundingAmount }
      );
      
      contractAddress = tx.logs.find(log => log.event === "ContractCreated").args.insuranceContract;
      insurance = await AutomatedInsuranceContract.at(contractAddress);
      
      const premiumETH = web3.utils.toWei("0.05", "ether");
      await provider.payPremium(contractAddress, { from: client1, value: premiumETH });
    });
    
    it("should handle performUpkeep when no upkeep is needed", async () => {
      // Try to perform upkeep without enough time passing
      const emptyBatch = web3.eth.abi.encodeParameter('address[]', []);
      
      await expectRevert(
        provider.performUpkeep(emptyBatch),
        "Upkeep not needed"
      );
    });
    
    it("should handle empty contract batch gracefully", async () => {
      // Deactivate all contracts
      await provider.deactivateContract(contractAddress, { from: owner });
      
      // Advance time
      await time.increase(UPKEEP_INTERVAL + 1);
      
      // Should not need upkeep with no active contracts
      const checkResult = await provider.checkUpkeep("0x");
      expect(checkResult.upkeepNeeded).to.be.false;
    });
    
    it("should handle contract that becomes inactive during batch processing", async () => {
      // This would be handled by the try-catch in performUpkeep
      // Contract silently fails but others continue processing
      
      await time.increase(UPKEEP_INTERVAL + 1);
      const checkResult = await provider.checkUpkeep("0x");
      
      // Deactivate contract right before upkeep
      await provider.deactivateContract(contractAddress, { from: owner });
      
      // Upkeep should still work (will skip inactive contract)
      const tx = await provider.performUpkeep(checkResult.performData);
      
      // Should process 0 contracts but not fail
      expectEvent(tx, "AutomationUpkeepPerformed", {
        contractsProcessed: "0"
      });
    });
  });
  
  describe("Manual Override Functions", () => {
    let contractAddress, insurance;
    
    beforeEach(async () => {
      const fundingAmount = web3.utils.toWei("1", "ether");
      const tx = await provider.newContract(
        client1,
        duration,
        premiumUSD,
        payoutUSD,
        location,
        "0x0000000000000000000000000000000000000000",
        { from: owner, value: fundingAmount }
      );
      
      contractAddress = tx.logs.find(log => log.event === "ContractCreated").args.insuranceContract;
      insurance = await AutomatedInsuranceContract.at(contractAddress);
      
      const premiumETH = web3.utils.toWei("0.05", "ether");
      await provider.payPremium(contractAddress, { from: client1, value: premiumETH });
    });
    
    it("should allow manual weather updates by owner", async () => {
      const tx = await provider.manualWeatherUpdate([contractAddress], { from: owner });
      
      // Should trigger weather check on the contract
      // This would emit events from the individual contract
    });
    
    it("should allow automation to be toggled", async () => {
      // Disable automation
      await provider.setAutomationEnabled(false, { from: owner });
      expect(await provider.automationEnabled()).to.be.false;
      
      // Re-enable automation
      await provider.setAutomationEnabled(true, { from: owner });
      expect(await provider.automationEnabled()).to.be.true;
    });
    
    it("should allow upkeep interval to be modified", async () => {
      const newInterval = 2 * DAY_IN_SECONDS; // 2 days
      await provider.setUpkeepInterval(newInterval, { from: owner });
      
      expect(await provider.upkeepInterval()).to.be.bignumber.equal(new BN(newInterval));
    });
    
    it("should not allow upkeep interval less than 1 hour", async () => {
      const tooShort = 3000; // 50 minutes
      
      await expectRevert(
        provider.setUpkeepInterval(tooShort, { from: owner }),
        "Minimum 1 hour interval"
      );
    });
  });
});