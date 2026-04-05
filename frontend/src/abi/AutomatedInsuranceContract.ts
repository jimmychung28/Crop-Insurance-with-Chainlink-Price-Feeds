export const automatedInsuranceContractAbi = [
  // Read functions
  { type: 'function', name: 'client', inputs: [], outputs: [{ type: 'address' }], stateMutability: 'view' },
  { type: 'function', name: 'insurer', inputs: [], outputs: [{ type: 'address' }], stateMutability: 'view' },
  { type: 'function', name: 'cropLocation', inputs: [], outputs: [{ type: 'string' }], stateMutability: 'view' },
  { type: 'function', name: 'premium', inputs: [], outputs: [{ type: 'uint256' }], stateMutability: 'view' },
  { type: 'function', name: 'payoutValue', inputs: [], outputs: [{ type: 'uint256' }], stateMutability: 'view' },
  { type: 'function', name: 'duration', inputs: [], outputs: [{ type: 'uint256' }], stateMutability: 'view' },
  { type: 'function', name: 'startDate', inputs: [], outputs: [{ type: 'uint256' }], stateMutability: 'view' },
  { type: 'function', name: 'activatedAt', inputs: [], outputs: [{ type: 'uint256' }], stateMutability: 'view' },
  { type: 'function', name: 'lastWeatherCheck', inputs: [], outputs: [{ type: 'uint256' }], stateMutability: 'view' },
  { type: 'function', name: 'paymentToken', inputs: [], outputs: [{ type: 'address' }], stateMutability: 'view' },
  { type: 'function', name: 'currentRainfall', inputs: [], outputs: [{ type: 'uint256' }], stateMutability: 'view' },
  { type: 'function', name: 'daysWithoutRain', inputs: [], outputs: [{ type: 'uint256' }], stateMutability: 'view' },
  { type: 'function', name: 'contractActive', inputs: [], outputs: [{ type: 'bool' }], stateMutability: 'view' },
  { type: 'function', name: 'contractPaid', inputs: [], outputs: [{ type: 'bool' }], stateMutability: 'view' },
  { type: 'function', name: 'premiumPaid', inputs: [], outputs: [{ type: 'bool' }], stateMutability: 'view' },
  { type: 'function', name: 'requestCount', inputs: [], outputs: [{ type: 'uint256' }], stateMutability: 'view' },
  { type: 'function', name: 'isActive', inputs: [], outputs: [{ type: 'bool' }], stateMutability: 'view' },
  { type: 'function', name: 'needsWeatherUpdate', inputs: [], outputs: [{ type: 'bool' }], stateMutability: 'view' },
  { type: 'function', name: 'getContractBalance', inputs: [], outputs: [{ type: 'uint256' }], stateMutability: 'view' },
  { type: 'function', name: 'getLocation', inputs: [], outputs: [{ type: 'string' }], stateMutability: 'view' },
  { type: 'function', name: 'getPayoutValue', inputs: [], outputs: [{ type: 'uint256' }], stateMutability: 'view' },
  { type: 'function', name: 'getPremium', inputs: [], outputs: [{ type: 'uint256' }], stateMutability: 'view' },
  { type: 'function', name: 'getContractStatus', inputs: [], outputs: [{ type: 'bool' }], stateMutability: 'view' },
  { type: 'function', name: 'getCurrentRainfall', inputs: [], outputs: [{ type: 'uint256' }], stateMutability: 'view' },
  { type: 'function', name: 'getRequestCount', inputs: [], outputs: [{ type: 'uint256' }], stateMutability: 'view' },
  { type: 'function', name: 'getDaysWithoutRain', inputs: [], outputs: [{ type: 'uint256' }], stateMutability: 'view' },
  { type: 'function', name: 'getChainlinkToken', inputs: [], outputs: [{ type: 'address' }], stateMutability: 'view' },
  { type: 'function', name: 'getLatestPrice', inputs: [], outputs: [{ type: 'int256' }], stateMutability: 'view' },

  // Events
  {
    type: 'event', name: 'contractPaidOut',
    inputs: [
      { name: '_paidTime', type: 'uint256', indexed: false },
      { name: '_totalPaid', type: 'uint256', indexed: false },
      { name: '_finalRainfall', type: 'uint256', indexed: false },
    ],
  },
  {
    type: 'event', name: 'contractEnded',
    inputs: [
      { name: '_endTime', type: 'uint256', indexed: false },
      { name: '_totalReturned', type: 'uint256', indexed: false },
    ],
  },
  {
    type: 'event', name: 'contractActivated',
    inputs: [{ name: '_activatedAt', type: 'uint256', indexed: false }],
  },
  {
    type: 'event', name: 'dataReceived',
    inputs: [{ name: '_rainfall', type: 'uint256', indexed: false }],
  },
  {
    type: 'event', name: 'RainfallThresholdReset',
    inputs: [{ name: 'rainfall', type: 'uint256', indexed: false }],
  },
  {
    type: 'event', name: 'AutomatedWeatherCheckPerformed',
    inputs: [
      { name: 'timestamp', type: 'uint256', indexed: false },
      { name: 'rainfall', type: 'uint256', indexed: false },
    ],
  },
] as const
