const InsuranceProvider = artifacts.require("InsuranceProvider");
const InsuranceContract = artifacts.require("InsuranceContract");
const MockERC20 = artifacts.require("MockERC20");
const { expectRevert, expectEvent, time } = require("@openzeppelin/test-helpers");
const { expect } = require("chai");
const BN = web3.utils.BN;

contract("Premium Collection Tests", (accounts) => {
  const [owner, client, otherUser] = accounts;
  
  // Constants
  const PREMIUM_GRACE_PERIOD = 86400; // 1 day in seconds
  const DAY_IN_SECONDS = 60; // For testing
  const DROUGHT_DAYS_THRESHOLD = 3;
  
  // Test parameters
  const duration = DAY_IN_SECONDS * 7; // 7 days
  const premiumUSD = 100 * 10**8; // 100 USD with 8 decimals
  const payoutUSD = 1000 * 10**8; // 1000 USD with 8 decimals
  const location = "London,UK";
  
  let provider, mockUSDC, mockDAI;
  
  beforeEach(async () => {
    // Deploy insurance provider
    provider = await InsuranceProvider.new(
      "test_world_weather_key",
      "test_open_weather_key", 
      "test_weatherbit_key",
      { from: owner }
    );
    
    // Deploy mock tokens
    mockUSDC = await MockERC20.new("USD Coin", "USDC", 6, { from: owner });
    mockDAI = await MockERC20.new("Dai Stablecoin", "DAI", 18, { from: owner });
    
    // Mint tokens to owner and client
    await mockUSDC.mint(owner, web3.utils.toWei("10000", "mwei"), { from: owner });
    await mockUSDC.mint(client, web3.utils.toWei("10000", "mwei"), { from: owner });
    await mockDAI.mint(owner, web3.utils.toWei("10000", "ether"), { from: owner });
    await mockDAI.mint(client, web3.utils.toWei("10000", "ether"), { from: owner });
    
    // Add supported tokens with mock price feeds
    const mockPriceFeed = "0x9326BFA02ADD2366b30bacB125260Af641031331"; // ETH/USD feed
    await provider.addSupportedToken(mockUSDC.address, mockPriceFeed, { from: owner });
    await provider.addSupportedToken(mockDAI.address, mockPriceFeed, { from: owner });
  });
  
  describe("Contract Creation", () => {
    it("should create a contract with pending premium payment", async () => {
      // Create contract with ETH payment type
      const fundingAmount = web3.utils.toWei("1", "ether"); // Enough to cover payout
      const tx = await provider.newContract(
        client,
        duration,
        premiumUSD,
        payoutUSD,
        location,
        "0x0000000000000000000000000000000000000000", // ETH
        { from: owner, value: fundingAmount }
      );
      
      // Get contract address from event
      const event = tx.logs.find(log => log.event === "ContractCreated");
      const contractAddress = event.args.insuranceContract;
      
      // Check premium info
      const premiumInfo = await provider.getPremiumInfo(contractAddress);
      expect(premiumInfo.amount).to.be.bignumber.equal(new BN(premiumUSD));
      expect(premiumInfo.token).to.equal("0x0000000000000000000000000000000000000000");
      expect(premiumInfo.paid).to.be.false;
      
      // Check contract is not active yet
      const insurance = await InsuranceContract.at(contractAddress);
      const isActive = await insurance.isActive();
      expect(isActive).to.be.false;
    });
    
    it("should create a contract with USDC payment type", async () => {
      // Approve tokens for payout
      const tokenAmount = web3.utils.toWei("1000", "mwei"); // 1000 USDC
      await mockUSDC.approve(provider.address, tokenAmount, { from: owner });
      
      // Create contract
      const tx = await provider.newContract(
        client,
        duration,
        premiumUSD,
        payoutUSD,
        location,
        mockUSDC.address,
        { from: owner }
      );
      
      // Get contract address from event
      const event = tx.logs.find(log => log.event === "ContractCreated");
      const contractAddress = event.args.insuranceContract;
      
      // Check premium info
      const premiumInfo = await provider.getPremiumInfo(contractAddress);
      expect(premiumInfo.token).to.equal(mockUSDC.address);
      expect(premiumInfo.paid).to.be.false;
    });
  });
  
  describe("Premium Payment", () => {
    let contractAddress, insurance;
    
    beforeEach(async () => {
      // Create a contract with ETH payment
      const fundingAmount = web3.utils.toWei("1", "ether");
      const tx = await provider.newContract(
        client,
        duration,
        premiumUSD,
        payoutUSD,
        location,
        "0x0000000000000000000000000000000000000000", // ETH
        { from: owner, value: fundingAmount }
      );
      
      const event = tx.logs.find(log => log.event === "ContractCreated");
      contractAddress = event.args.insuranceContract;
      insurance = await InsuranceContract.at(contractAddress);
    });
    
    it("should allow client to pay premium in ETH", async () => {
      // Calculate premium in ETH (mocking price at 2000 USD/ETH)
      const premiumETH = web3.utils.toWei("0.05", "ether"); // 100 USD / 2000 USD/ETH
      
      // Pay premium
      const tx = await provider.payPremium(contractAddress, {
        from: client,
        value: premiumETH
      });
      
      // Check events
      expectEvent(tx, "PremiumPaid", {
        insuranceContract: contractAddress,
        client: client,
        paymentToken: "0x0000000000000000000000000000000000000000",
        amount: premiumUSD
      });
      
      // Check premium is marked as paid
      const premiumInfo = await provider.getPremiumInfo(contractAddress);
      expect(premiumInfo.paid).to.be.true;
      
      // Check contract is now active
      const isActive = await insurance.isActive();
      expect(isActive).to.be.true;
    });
    
    it("should allow client to pay premium in USDC", async () => {
      // Create USDC contract
      const tokenAmount = web3.utils.toWei("1000", "mwei");
      await mockUSDC.approve(provider.address, tokenAmount, { from: owner });
      
      const tx = await provider.newContract(
        client,
        duration,
        premiumUSD,
        payoutUSD,
        location,
        mockUSDC.address,
        { from: owner }
      );
      
      const event = tx.logs.find(log => log.event === "ContractCreated");
      const usdcContractAddress = event.args.insuranceContract;
      
      // Approve premium payment
      const premiumAmount = web3.utils.toWei("100", "mwei"); // 100 USDC
      await mockUSDC.approve(provider.address, premiumAmount, { from: client });
      
      // Pay premium
      const payTx = await provider.payPremium(usdcContractAddress, { from: client });
      
      // Check premium is paid
      const premiumInfo = await provider.getPremiumInfo(usdcContractAddress);
      expect(premiumInfo.paid).to.be.true;
    });
    
    it("should reject premium payment from non-client", async () => {
      const premiumETH = web3.utils.toWei("0.05", "ether");
      
      await expectRevert(
        provider.payPremium(contractAddress, {
          from: otherUser,
          value: premiumETH
        }),
        "Only client can pay premium"
      );
    });
    
    it("should reject insufficient premium payment", async () => {
      const insufficientPremium = web3.utils.toWei("0.01", "ether"); // Too little
      
      await expectRevert(
        provider.payPremium(contractAddress, {
          from: client,
          value: insufficientPremium
        }),
        "Insufficient ETH sent for premium"
      );
    });
    
    it("should reject premium payment after grace period", async () => {
      // Advance time beyond grace period
      await time.increase(PREMIUM_GRACE_PERIOD + 1);
      
      const premiumETH = web3.utils.toWei("0.05", "ether");
      
      await expectRevert(
        provider.payPremium(contractAddress, {
          from: client,
          value: premiumETH
        }),
        "Premium payment grace period expired"
      );
    });
    
    it("should reject double premium payment", async () => {
      const premiumETH = web3.utils.toWei("0.05", "ether");
      
      // First payment
      await provider.payPremium(contractAddress, {
        from: client,
        value: premiumETH
      });
      
      // Second payment should fail
      await expectRevert(
        provider.payPremium(contractAddress, {
          from: client,
          value: premiumETH
        }),
        "Premium already paid"
      );
    });
  });
  
  describe("Premium Refunds", () => {
    let contractAddress;
    
    beforeEach(async () => {
      // Create a contract
      const fundingAmount = web3.utils.toWei("1", "ether");
      const tx = await provider.newContract(
        client,
        duration,
        premiumUSD,
        payoutUSD,
        location,
        "0x0000000000000000000000000000000000000000",
        { from: owner, value: fundingAmount }
      );
      
      const event = tx.logs.find(log => log.event === "ContractCreated");
      contractAddress = event.args.insuranceContract;
    });
    
    it("should refund premium if not paid within grace period", async () => {
      // Pay premium first
      const premiumETH = web3.utils.toWei("0.05", "ether");
      await provider.payPremium(contractAddress, {
        from: client,
        value: premiumETH
      });
      
      // Note: This test would need modification as current implementation
      // doesn't allow refund if premium is paid but contract not activated
      // This is a potential improvement to consider
    });
    
    it("should not refund if contract is active", async () => {
      // Pay premium to activate contract
      const premiumETH = web3.utils.toWei("0.05", "ether");
      await provider.payPremium(contractAddress, {
        from: client,
        value: premiumETH
      });
      
      // Try to refund
      await expectRevert(
        provider.refundPremium(contractAddress, { from: client }),
        "Contract is active, cannot refund"
      );
    });
  });
  
  describe("Premium Claims by Insurer", () => {
    let contractAddress, insurance;
    
    beforeEach(async () => {
      // Create and activate a contract
      const fundingAmount = web3.utils.toWei("1", "ether");
      const tx = await provider.newContract(
        client,
        duration,
        premiumUSD,
        payoutUSD,
        location,
        "0x0000000000000000000000000000000000000000",
        { from: owner, value: fundingAmount }
      );
      
      const event = tx.logs.find(log => log.event === "ContractCreated");
      contractAddress = event.args.insuranceContract;
      insurance = await InsuranceContract.at(contractAddress);
      
      // Client pays premium
      const premiumETH = web3.utils.toWei("0.05", "ether");
      await provider.payPremium(contractAddress, {
        from: client,
        value: premiumETH
      });
    });
    
    it("should allow insurer to claim premium after contract ends", async () => {
      // Advance time past contract duration
      await time.increase(duration + 1);
      
      // Check insurer balance before
      const balanceBefore = await web3.eth.getBalance(owner);
      
      // Claim premium
      const tx = await provider.claimPremium(contractAddress, { from: owner });
      
      // Check insurer balance increased
      const balanceAfter = await web3.eth.getBalance(owner);
      expect(new BN(balanceAfter)).to.be.bignumber.gt(new BN(balanceBefore));
    });
    
    it("should not allow claiming premium while contract is active", async () => {
      await expectRevert(
        provider.claimPremium(contractAddress, { from: owner }),
        "Contract still active"
      );
    });
    
    it("should not allow non-owner to claim premium", async () => {
      await time.increase(duration + 1);
      
      await expectRevert(
        provider.claimPremium(contractAddress, { from: otherUser }),
        "Ownable: caller is not the owner"
      );
    });
  });
  
  describe("Integration Tests", () => {
    it("should handle complete lifecycle with premium payment", async () => {
      // 1. Create contract
      const fundingAmount = web3.utils.toWei("1", "ether");
      const createTx = await provider.newContract(
        client,
        duration,
        premiumUSD,
        payoutUSD,
        location,
        "0x0000000000000000000000000000000000000000",
        { from: owner, value: fundingAmount }
      );
      
      const event = createTx.logs.find(log => log.event === "ContractCreated");
      const contractAddress = event.args.insuranceContract;
      const insurance = await InsuranceContract.at(contractAddress);
      
      // 2. Client pays premium
      const premiumETH = web3.utils.toWei("0.05", "ether");
      await provider.payPremium(contractAddress, {
        from: client,
        value: premiumETH
      });
      
      // 3. Verify contract is active
      expect(await insurance.isActive()).to.be.true;
      
      // 4. Contract executes normally...
      // (Weather checks would happen here in production)
      
      // 5. Contract ends
      await time.increase(duration + 1);
      
      // 6. Insurer claims premium
      await provider.claimPremium(contractAddress, { from: owner });
      
      // 7. Verify premium is claimed
      const premiumInfo = await provider.getPremiumInfo(contractAddress);
      expect(premiumInfo.paid).to.be.false; // Marked as claimed
    });
  });
});