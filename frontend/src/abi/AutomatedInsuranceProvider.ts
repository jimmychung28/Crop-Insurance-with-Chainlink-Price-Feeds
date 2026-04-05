export const automatedInsuranceProviderAbi = [
  // Read functions
  { type: 'function', name: 'insurer', inputs: [], outputs: [{ type: 'address' }], stateMutability: 'view' },
  { type: 'function', name: 'easManager', inputs: [], outputs: [{ type: 'address' }], stateMutability: 'view' },
  { type: 'function', name: 'easEnabled', inputs: [], outputs: [{ type: 'bool' }], stateMutability: 'view' },
  { type: 'function', name: 'automationEnabled', inputs: [], outputs: [{ type: 'bool' }], stateMutability: 'view' },
  { type: 'function', name: 'upkeepInterval', inputs: [], outputs: [{ type: 'uint256' }], stateMutability: 'view' },
  { type: 'function', name: 'lastUpkeepTimestamp', inputs: [], outputs: [{ type: 'uint256' }], stateMutability: 'view' },
  { type: 'function', name: 'upkeepBatchCounter', inputs: [], outputs: [{ type: 'uint64' }], stateMutability: 'view' },
  { type: 'function', name: 'supportedTokens', inputs: [{ type: 'address' }], outputs: [{ type: 'bool' }], stateMutability: 'view' },
  { type: 'function', name: 'USDC', inputs: [], outputs: [{ type: 'address' }], stateMutability: 'view' },
  { type: 'function', name: 'DAI', inputs: [], outputs: [{ type: 'address' }], stateMutability: 'view' },
  { type: 'function', name: 'USDT', inputs: [], outputs: [{ type: 'address' }], stateMutability: 'view' },
  {
    type: 'function', name: 'premiumInfo', inputs: [{ type: 'address' }],
    outputs: [
      { name: 'amount', type: 'uint128' },
      { name: 'amountPaid', type: 'uint128' },
      { name: 'paidAt', type: 'uint64' },
      { name: 'createdAt', type: 'uint64' },
      { name: 'token', type: 'address' },
      { name: 'paid', type: 'bool' },
    ],
    stateMutability: 'view',
  },
  { type: 'function', name: 'getActiveContractsCount', inputs: [], outputs: [{ type: 'uint256' }], stateMutability: 'view' },
  {
    type: 'function', name: 'getActiveContracts',
    inputs: [{ name: 'start', type: 'uint256' }, { name: 'limit', type: 'uint256' }],
    outputs: [{ type: 'address[]' }],
    stateMutability: 'view',
  },
  { type: 'function', name: 'getContractsByClient', inputs: [{ name: '_client', type: 'address' }], outputs: [{ type: 'address[]' }], stateMutability: 'view' },
  { type: 'function', name: 'getLatestPrice', inputs: [], outputs: [{ type: 'int256' }], stateMutability: 'view' },
  {
    type: 'function', name: 'getTokenAmountForUSD',
    inputs: [{ name: 'token', type: 'address' }, { name: 'usdAmount', type: 'uint256' }],
    outputs: [{ type: 'uint256' }],
    stateMutability: 'view',
  },
  { type: 'function', name: 'getEASManager', inputs: [], outputs: [{ type: 'address' }], stateMutability: 'view' },
  { type: 'function', name: 'isEASEnabled', inputs: [], outputs: [{ type: 'bool' }], stateMutability: 'view' },
  { type: 'function', name: 'PREMIUM_GRACE_PERIOD', inputs: [], outputs: [{ type: 'uint256' }], stateMutability: 'view' },
  { type: 'function', name: 'MAX_CONTRACTS_PER_BATCH', inputs: [], outputs: [{ type: 'uint256' }], stateMutability: 'view' },

  // Write functions
  {
    type: 'function', name: 'newContract',
    inputs: [
      { name: '_client', type: 'address' },
      { name: '_duration', type: 'uint256' },
      { name: '_premium', type: 'uint256' },
      { name: '_payoutValue', type: 'uint256' },
      { name: '_cropLocation', type: 'string' },
      { name: '_paymentToken', type: 'address' },
    ],
    outputs: [{ type: 'address' }],
    stateMutability: 'payable',
  },
  { type: 'function', name: 'payPremium', inputs: [{ name: '_contract', type: 'address' }], outputs: [], stateMutability: 'payable' },
  { type: 'function', name: 'refundPremium', inputs: [{ name: '_contract', type: 'address' }], outputs: [], stateMutability: 'nonpayable' },
  { type: 'function', name: 'claimPremium', inputs: [{ name: '_contract', type: 'address' }], outputs: [], stateMutability: 'nonpayable' },
  { type: 'function', name: 'setAutomationEnabled', inputs: [{ name: '_enabled', type: 'bool' }], outputs: [], stateMutability: 'nonpayable' },
  { type: 'function', name: 'setUpkeepInterval', inputs: [{ name: '_interval', type: 'uint256' }], outputs: [], stateMutability: 'nonpayable' },
  { type: 'function', name: 'manualWeatherUpdate', inputs: [{ name: '_contracts', type: 'address[]' }], outputs: [], stateMutability: 'nonpayable' },
  {
    type: 'function', name: 'addSupportedToken',
    inputs: [{ name: 'token', type: 'address' }, { name: 'priceFeed', type: 'address' }],
    outputs: [],
    stateMutability: 'nonpayable',
  },

  // Events
  {
    type: 'event', name: 'ContractCreated',
    inputs: [
      { name: 'insuranceContract', type: 'address', indexed: true },
      { name: 'client', type: 'address', indexed: true },
      { name: 'configHash', type: 'bytes32', indexed: true },
    ],
  },
  {
    type: 'event', name: 'PremiumPaid',
    inputs: [
      { name: 'insuranceContract', type: 'address', indexed: true },
      { name: 'client', type: 'address', indexed: true },
      { name: 'amount', type: 'uint128', indexed: false },
      { name: 'token', type: 'address', indexed: false },
    ],
  },
  {
    type: 'event', name: 'ContractStateChanged',
    inputs: [
      { name: 'contractAddress', type: 'address', indexed: true },
      { name: 'isActive', type: 'bool', indexed: true },
    ],
  },
  {
    type: 'event', name: 'PremiumRefunded',
    inputs: [
      { name: 'insuranceContract', type: 'address', indexed: true },
      { name: 'client', type: 'address', indexed: true },
      { name: 'amount', type: 'uint128', indexed: false },
      { name: 'token', type: 'address', indexed: false },
    ],
  },
  {
    type: 'event', name: 'PremiumClaimed',
    inputs: [
      { name: 'insuranceContract', type: 'address', indexed: true },
      { name: 'insurer_', type: 'address', indexed: true },
      { name: 'amount', type: 'uint128', indexed: false },
      { name: 'token', type: 'address', indexed: false },
    ],
  },
  {
    type: 'event', name: 'AutomationUpkeepPerformed',
    inputs: [
      { name: 'batchId', type: 'uint64', indexed: true },
      { name: 'contractsProcessed', type: 'uint32', indexed: false },
      { name: 'gasUsed', type: 'uint32', indexed: false },
    ],
  },
  {
    type: 'event', name: 'AttestationCreated',
    inputs: [
      { name: 'contract_', type: 'address', indexed: true },
      { name: 'attestationType', type: 'uint8', indexed: true },
      { name: 'uid', type: 'bytes32', indexed: false },
    ],
  },
] as const
