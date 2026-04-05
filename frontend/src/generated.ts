import {
  createUseReadContract,
  createUseWatchContractEvent,
  createUseWriteContract,
  createUseSimulateContract,
} from 'wagmi/codegen'

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// AutomatedInsuranceContract
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const automatedInsuranceContractAbi = [
  {
    type: 'function',
    inputs: [],
    name: 'client',
    outputs: [{ type: 'address' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'insurer',
    outputs: [{ type: 'address' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'cropLocation',
    outputs: [{ type: 'string' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'premium',
    outputs: [{ type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'payoutValue',
    outputs: [{ type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'duration',
    outputs: [{ type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'startDate',
    outputs: [{ type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'activatedAt',
    outputs: [{ type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'lastWeatherCheck',
    outputs: [{ type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'paymentToken',
    outputs: [{ type: 'address' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'currentRainfall',
    outputs: [{ type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'daysWithoutRain',
    outputs: [{ type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'contractActive',
    outputs: [{ type: 'bool' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'contractPaid',
    outputs: [{ type: 'bool' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'premiumPaid',
    outputs: [{ type: 'bool' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'requestCount',
    outputs: [{ type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'isActive',
    outputs: [{ type: 'bool' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'needsWeatherUpdate',
    outputs: [{ type: 'bool' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'getContractBalance',
    outputs: [{ type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'getLocation',
    outputs: [{ type: 'string' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'getPayoutValue',
    outputs: [{ type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'getPremium',
    outputs: [{ type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'getContractStatus',
    outputs: [{ type: 'bool' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'getCurrentRainfall',
    outputs: [{ type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'getRequestCount',
    outputs: [{ type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'getDaysWithoutRain',
    outputs: [{ type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'getChainlinkToken',
    outputs: [{ type: 'address' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'getLatestPrice',
    outputs: [{ type: 'int256' }],
    stateMutability: 'view',
  },
  {
    type: 'event',
    inputs: [
      { name: '_paidTime', type: 'uint256', indexed: false },
      { name: '_totalPaid', type: 'uint256', indexed: false },
      { name: '_finalRainfall', type: 'uint256', indexed: false },
    ],
    name: 'contractPaidOut',
  },
  {
    type: 'event',
    inputs: [
      { name: '_endTime', type: 'uint256', indexed: false },
      { name: '_totalReturned', type: 'uint256', indexed: false },
    ],
    name: 'contractEnded',
  },
  {
    type: 'event',
    inputs: [{ name: '_activatedAt', type: 'uint256', indexed: false }],
    name: 'contractActivated',
  },
  {
    type: 'event',
    inputs: [{ name: '_rainfall', type: 'uint256', indexed: false }],
    name: 'dataReceived',
  },
  {
    type: 'event',
    inputs: [{ name: 'rainfall', type: 'uint256', indexed: false }],
    name: 'RainfallThresholdReset',
  },
  {
    type: 'event',
    inputs: [
      { name: 'timestamp', type: 'uint256', indexed: false },
      { name: 'rainfall', type: 'uint256', indexed: false },
    ],
    name: 'AutomatedWeatherCheckPerformed',
  },
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// AutomatedInsuranceProvider
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const automatedInsuranceProviderAbi = [
  {
    type: 'function',
    inputs: [],
    name: 'insurer',
    outputs: [{ type: 'address' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'easManager',
    outputs: [{ type: 'address' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'easEnabled',
    outputs: [{ type: 'bool' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'automationEnabled',
    outputs: [{ type: 'bool' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'upkeepInterval',
    outputs: [{ type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'lastUpkeepTimestamp',
    outputs: [{ type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'upkeepBatchCounter',
    outputs: [{ type: 'uint64' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [{ type: 'address' }],
    name: 'supportedTokens',
    outputs: [{ type: 'bool' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'USDC',
    outputs: [{ type: 'address' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'DAI',
    outputs: [{ type: 'address' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'USDT',
    outputs: [{ type: 'address' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [{ type: 'address' }],
    name: 'premiumInfo',
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
  {
    type: 'function',
    inputs: [],
    name: 'getActiveContractsCount',
    outputs: [{ type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [
      { name: 'start', type: 'uint256' },
      { name: 'limit', type: 'uint256' },
    ],
    name: 'getActiveContracts',
    outputs: [{ type: 'address[]' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [{ name: '_client', type: 'address' }],
    name: 'getContractsByClient',
    outputs: [{ type: 'address[]' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'getLatestPrice',
    outputs: [{ type: 'int256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [
      { name: 'token', type: 'address' },
      { name: 'usdAmount', type: 'uint256' },
    ],
    name: 'getTokenAmountForUSD',
    outputs: [{ type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'getEASManager',
    outputs: [{ type: 'address' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'isEASEnabled',
    outputs: [{ type: 'bool' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'PREMIUM_GRACE_PERIOD',
    outputs: [{ type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'MAX_CONTRACTS_PER_BATCH',
    outputs: [{ type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [
      { name: '_client', type: 'address' },
      { name: '_duration', type: 'uint256' },
      { name: '_premium', type: 'uint256' },
      { name: '_payoutValue', type: 'uint256' },
      { name: '_cropLocation', type: 'string' },
      { name: '_paymentToken', type: 'address' },
    ],
    name: 'newContract',
    outputs: [{ type: 'address' }],
    stateMutability: 'payable',
  },
  {
    type: 'function',
    inputs: [{ name: '_contract', type: 'address' }],
    name: 'payPremium',
    outputs: [],
    stateMutability: 'payable',
  },
  {
    type: 'function',
    inputs: [{ name: '_contract', type: 'address' }],
    name: 'refundPremium',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [{ name: '_contract', type: 'address' }],
    name: 'claimPremium',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [{ name: '_enabled', type: 'bool' }],
    name: 'setAutomationEnabled',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [{ name: '_interval', type: 'uint256' }],
    name: 'setUpkeepInterval',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [{ name: '_contracts', type: 'address[]' }],
    name: 'manualWeatherUpdate',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      { name: 'token', type: 'address' },
      { name: 'priceFeed', type: 'address' },
    ],
    name: 'addSupportedToken',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'event',
    inputs: [
      { name: 'insuranceContract', type: 'address', indexed: true },
      { name: 'client', type: 'address', indexed: true },
      { name: 'configHash', type: 'bytes32', indexed: true },
    ],
    name: 'ContractCreated',
  },
  {
    type: 'event',
    inputs: [
      { name: 'insuranceContract', type: 'address', indexed: true },
      { name: 'client', type: 'address', indexed: true },
      { name: 'amount', type: 'uint128', indexed: false },
      { name: 'token', type: 'address', indexed: false },
    ],
    name: 'PremiumPaid',
  },
  {
    type: 'event',
    inputs: [
      { name: 'contractAddress', type: 'address', indexed: true },
      { name: 'isActive', type: 'bool', indexed: true },
    ],
    name: 'ContractStateChanged',
  },
  {
    type: 'event',
    inputs: [
      { name: 'insuranceContract', type: 'address', indexed: true },
      { name: 'client', type: 'address', indexed: true },
      { name: 'amount', type: 'uint128', indexed: false },
      { name: 'token', type: 'address', indexed: false },
    ],
    name: 'PremiumRefunded',
  },
  {
    type: 'event',
    inputs: [
      { name: 'insuranceContract', type: 'address', indexed: true },
      { name: 'insurer_', type: 'address', indexed: true },
      { name: 'amount', type: 'uint128', indexed: false },
      { name: 'token', type: 'address', indexed: false },
    ],
    name: 'PremiumClaimed',
  },
  {
    type: 'event',
    inputs: [
      { name: 'batchId', type: 'uint64', indexed: true },
      { name: 'contractsProcessed', type: 'uint32', indexed: false },
      { name: 'gasUsed', type: 'uint32', indexed: false },
    ],
    name: 'AutomationUpkeepPerformed',
  },
  {
    type: 'event',
    inputs: [
      { name: 'contract_', type: 'address', indexed: true },
      { name: 'attestationType', type: 'uint8', indexed: true },
      { name: 'uid', type: 'bytes32', indexed: false },
    ],
    name: 'AttestationCreated',
  },
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// React
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link automatedInsuranceContractAbi}__
 */
export const useReadAutomatedInsuranceContract =
  /*#__PURE__*/ createUseReadContract({ abi: automatedInsuranceContractAbi })

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link automatedInsuranceContractAbi}__ and `functionName` set to `"client"`
 */
export const useReadAutomatedInsuranceContractClient =
  /*#__PURE__*/ createUseReadContract({
    abi: automatedInsuranceContractAbi,
    functionName: 'client',
  })

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link automatedInsuranceContractAbi}__ and `functionName` set to `"insurer"`
 */
export const useReadAutomatedInsuranceContractInsurer =
  /*#__PURE__*/ createUseReadContract({
    abi: automatedInsuranceContractAbi,
    functionName: 'insurer',
  })

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link automatedInsuranceContractAbi}__ and `functionName` set to `"cropLocation"`
 */
export const useReadAutomatedInsuranceContractCropLocation =
  /*#__PURE__*/ createUseReadContract({
    abi: automatedInsuranceContractAbi,
    functionName: 'cropLocation',
  })

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link automatedInsuranceContractAbi}__ and `functionName` set to `"premium"`
 */
export const useReadAutomatedInsuranceContractPremium =
  /*#__PURE__*/ createUseReadContract({
    abi: automatedInsuranceContractAbi,
    functionName: 'premium',
  })

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link automatedInsuranceContractAbi}__ and `functionName` set to `"payoutValue"`
 */
export const useReadAutomatedInsuranceContractPayoutValue =
  /*#__PURE__*/ createUseReadContract({
    abi: automatedInsuranceContractAbi,
    functionName: 'payoutValue',
  })

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link automatedInsuranceContractAbi}__ and `functionName` set to `"duration"`
 */
export const useReadAutomatedInsuranceContractDuration =
  /*#__PURE__*/ createUseReadContract({
    abi: automatedInsuranceContractAbi,
    functionName: 'duration',
  })

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link automatedInsuranceContractAbi}__ and `functionName` set to `"startDate"`
 */
export const useReadAutomatedInsuranceContractStartDate =
  /*#__PURE__*/ createUseReadContract({
    abi: automatedInsuranceContractAbi,
    functionName: 'startDate',
  })

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link automatedInsuranceContractAbi}__ and `functionName` set to `"activatedAt"`
 */
export const useReadAutomatedInsuranceContractActivatedAt =
  /*#__PURE__*/ createUseReadContract({
    abi: automatedInsuranceContractAbi,
    functionName: 'activatedAt',
  })

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link automatedInsuranceContractAbi}__ and `functionName` set to `"lastWeatherCheck"`
 */
export const useReadAutomatedInsuranceContractLastWeatherCheck =
  /*#__PURE__*/ createUseReadContract({
    abi: automatedInsuranceContractAbi,
    functionName: 'lastWeatherCheck',
  })

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link automatedInsuranceContractAbi}__ and `functionName` set to `"paymentToken"`
 */
export const useReadAutomatedInsuranceContractPaymentToken =
  /*#__PURE__*/ createUseReadContract({
    abi: automatedInsuranceContractAbi,
    functionName: 'paymentToken',
  })

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link automatedInsuranceContractAbi}__ and `functionName` set to `"currentRainfall"`
 */
export const useReadAutomatedInsuranceContractCurrentRainfall =
  /*#__PURE__*/ createUseReadContract({
    abi: automatedInsuranceContractAbi,
    functionName: 'currentRainfall',
  })

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link automatedInsuranceContractAbi}__ and `functionName` set to `"daysWithoutRain"`
 */
export const useReadAutomatedInsuranceContractDaysWithoutRain =
  /*#__PURE__*/ createUseReadContract({
    abi: automatedInsuranceContractAbi,
    functionName: 'daysWithoutRain',
  })

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link automatedInsuranceContractAbi}__ and `functionName` set to `"contractActive"`
 */
export const useReadAutomatedInsuranceContractContractActive =
  /*#__PURE__*/ createUseReadContract({
    abi: automatedInsuranceContractAbi,
    functionName: 'contractActive',
  })

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link automatedInsuranceContractAbi}__ and `functionName` set to `"contractPaid"`
 */
export const useReadAutomatedInsuranceContractContractPaid =
  /*#__PURE__*/ createUseReadContract({
    abi: automatedInsuranceContractAbi,
    functionName: 'contractPaid',
  })

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link automatedInsuranceContractAbi}__ and `functionName` set to `"premiumPaid"`
 */
export const useReadAutomatedInsuranceContractPremiumPaid =
  /*#__PURE__*/ createUseReadContract({
    abi: automatedInsuranceContractAbi,
    functionName: 'premiumPaid',
  })

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link automatedInsuranceContractAbi}__ and `functionName` set to `"requestCount"`
 */
export const useReadAutomatedInsuranceContractRequestCount =
  /*#__PURE__*/ createUseReadContract({
    abi: automatedInsuranceContractAbi,
    functionName: 'requestCount',
  })

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link automatedInsuranceContractAbi}__ and `functionName` set to `"isActive"`
 */
export const useReadAutomatedInsuranceContractIsActive =
  /*#__PURE__*/ createUseReadContract({
    abi: automatedInsuranceContractAbi,
    functionName: 'isActive',
  })

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link automatedInsuranceContractAbi}__ and `functionName` set to `"needsWeatherUpdate"`
 */
export const useReadAutomatedInsuranceContractNeedsWeatherUpdate =
  /*#__PURE__*/ createUseReadContract({
    abi: automatedInsuranceContractAbi,
    functionName: 'needsWeatherUpdate',
  })

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link automatedInsuranceContractAbi}__ and `functionName` set to `"getContractBalance"`
 */
export const useReadAutomatedInsuranceContractGetContractBalance =
  /*#__PURE__*/ createUseReadContract({
    abi: automatedInsuranceContractAbi,
    functionName: 'getContractBalance',
  })

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link automatedInsuranceContractAbi}__ and `functionName` set to `"getLocation"`
 */
export const useReadAutomatedInsuranceContractGetLocation =
  /*#__PURE__*/ createUseReadContract({
    abi: automatedInsuranceContractAbi,
    functionName: 'getLocation',
  })

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link automatedInsuranceContractAbi}__ and `functionName` set to `"getPayoutValue"`
 */
export const useReadAutomatedInsuranceContractGetPayoutValue =
  /*#__PURE__*/ createUseReadContract({
    abi: automatedInsuranceContractAbi,
    functionName: 'getPayoutValue',
  })

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link automatedInsuranceContractAbi}__ and `functionName` set to `"getPremium"`
 */
export const useReadAutomatedInsuranceContractGetPremium =
  /*#__PURE__*/ createUseReadContract({
    abi: automatedInsuranceContractAbi,
    functionName: 'getPremium',
  })

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link automatedInsuranceContractAbi}__ and `functionName` set to `"getContractStatus"`
 */
export const useReadAutomatedInsuranceContractGetContractStatus =
  /*#__PURE__*/ createUseReadContract({
    abi: automatedInsuranceContractAbi,
    functionName: 'getContractStatus',
  })

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link automatedInsuranceContractAbi}__ and `functionName` set to `"getCurrentRainfall"`
 */
export const useReadAutomatedInsuranceContractGetCurrentRainfall =
  /*#__PURE__*/ createUseReadContract({
    abi: automatedInsuranceContractAbi,
    functionName: 'getCurrentRainfall',
  })

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link automatedInsuranceContractAbi}__ and `functionName` set to `"getRequestCount"`
 */
export const useReadAutomatedInsuranceContractGetRequestCount =
  /*#__PURE__*/ createUseReadContract({
    abi: automatedInsuranceContractAbi,
    functionName: 'getRequestCount',
  })

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link automatedInsuranceContractAbi}__ and `functionName` set to `"getDaysWithoutRain"`
 */
export const useReadAutomatedInsuranceContractGetDaysWithoutRain =
  /*#__PURE__*/ createUseReadContract({
    abi: automatedInsuranceContractAbi,
    functionName: 'getDaysWithoutRain',
  })

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link automatedInsuranceContractAbi}__ and `functionName` set to `"getChainlinkToken"`
 */
export const useReadAutomatedInsuranceContractGetChainlinkToken =
  /*#__PURE__*/ createUseReadContract({
    abi: automatedInsuranceContractAbi,
    functionName: 'getChainlinkToken',
  })

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link automatedInsuranceContractAbi}__ and `functionName` set to `"getLatestPrice"`
 */
export const useReadAutomatedInsuranceContractGetLatestPrice =
  /*#__PURE__*/ createUseReadContract({
    abi: automatedInsuranceContractAbi,
    functionName: 'getLatestPrice',
  })

/**
 * Wraps __{@link useWatchContractEvent}__ with `abi` set to __{@link automatedInsuranceContractAbi}__
 */
export const useWatchAutomatedInsuranceContractEvent =
  /*#__PURE__*/ createUseWatchContractEvent({
    abi: automatedInsuranceContractAbi,
  })

/**
 * Wraps __{@link useWatchContractEvent}__ with `abi` set to __{@link automatedInsuranceContractAbi}__ and `eventName` set to `"contractPaidOut"`
 */
export const useWatchAutomatedInsuranceContractContractPaidOutEvent =
  /*#__PURE__*/ createUseWatchContractEvent({
    abi: automatedInsuranceContractAbi,
    eventName: 'contractPaidOut',
  })

/**
 * Wraps __{@link useWatchContractEvent}__ with `abi` set to __{@link automatedInsuranceContractAbi}__ and `eventName` set to `"contractEnded"`
 */
export const useWatchAutomatedInsuranceContractContractEndedEvent =
  /*#__PURE__*/ createUseWatchContractEvent({
    abi: automatedInsuranceContractAbi,
    eventName: 'contractEnded',
  })

/**
 * Wraps __{@link useWatchContractEvent}__ with `abi` set to __{@link automatedInsuranceContractAbi}__ and `eventName` set to `"contractActivated"`
 */
export const useWatchAutomatedInsuranceContractContractActivatedEvent =
  /*#__PURE__*/ createUseWatchContractEvent({
    abi: automatedInsuranceContractAbi,
    eventName: 'contractActivated',
  })

/**
 * Wraps __{@link useWatchContractEvent}__ with `abi` set to __{@link automatedInsuranceContractAbi}__ and `eventName` set to `"dataReceived"`
 */
export const useWatchAutomatedInsuranceContractDataReceivedEvent =
  /*#__PURE__*/ createUseWatchContractEvent({
    abi: automatedInsuranceContractAbi,
    eventName: 'dataReceived',
  })

/**
 * Wraps __{@link useWatchContractEvent}__ with `abi` set to __{@link automatedInsuranceContractAbi}__ and `eventName` set to `"RainfallThresholdReset"`
 */
export const useWatchAutomatedInsuranceContractRainfallThresholdResetEvent =
  /*#__PURE__*/ createUseWatchContractEvent({
    abi: automatedInsuranceContractAbi,
    eventName: 'RainfallThresholdReset',
  })

/**
 * Wraps __{@link useWatchContractEvent}__ with `abi` set to __{@link automatedInsuranceContractAbi}__ and `eventName` set to `"AutomatedWeatherCheckPerformed"`
 */
export const useWatchAutomatedInsuranceContractAutomatedWeatherCheckPerformedEvent =
  /*#__PURE__*/ createUseWatchContractEvent({
    abi: automatedInsuranceContractAbi,
    eventName: 'AutomatedWeatherCheckPerformed',
  })

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link automatedInsuranceProviderAbi}__
 */
export const useReadAutomatedInsuranceProvider =
  /*#__PURE__*/ createUseReadContract({ abi: automatedInsuranceProviderAbi })

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link automatedInsuranceProviderAbi}__ and `functionName` set to `"insurer"`
 */
export const useReadAutomatedInsuranceProviderInsurer =
  /*#__PURE__*/ createUseReadContract({
    abi: automatedInsuranceProviderAbi,
    functionName: 'insurer',
  })

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link automatedInsuranceProviderAbi}__ and `functionName` set to `"easManager"`
 */
export const useReadAutomatedInsuranceProviderEasManager =
  /*#__PURE__*/ createUseReadContract({
    abi: automatedInsuranceProviderAbi,
    functionName: 'easManager',
  })

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link automatedInsuranceProviderAbi}__ and `functionName` set to `"easEnabled"`
 */
export const useReadAutomatedInsuranceProviderEasEnabled =
  /*#__PURE__*/ createUseReadContract({
    abi: automatedInsuranceProviderAbi,
    functionName: 'easEnabled',
  })

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link automatedInsuranceProviderAbi}__ and `functionName` set to `"automationEnabled"`
 */
export const useReadAutomatedInsuranceProviderAutomationEnabled =
  /*#__PURE__*/ createUseReadContract({
    abi: automatedInsuranceProviderAbi,
    functionName: 'automationEnabled',
  })

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link automatedInsuranceProviderAbi}__ and `functionName` set to `"upkeepInterval"`
 */
export const useReadAutomatedInsuranceProviderUpkeepInterval =
  /*#__PURE__*/ createUseReadContract({
    abi: automatedInsuranceProviderAbi,
    functionName: 'upkeepInterval',
  })

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link automatedInsuranceProviderAbi}__ and `functionName` set to `"lastUpkeepTimestamp"`
 */
export const useReadAutomatedInsuranceProviderLastUpkeepTimestamp =
  /*#__PURE__*/ createUseReadContract({
    abi: automatedInsuranceProviderAbi,
    functionName: 'lastUpkeepTimestamp',
  })

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link automatedInsuranceProviderAbi}__ and `functionName` set to `"upkeepBatchCounter"`
 */
export const useReadAutomatedInsuranceProviderUpkeepBatchCounter =
  /*#__PURE__*/ createUseReadContract({
    abi: automatedInsuranceProviderAbi,
    functionName: 'upkeepBatchCounter',
  })

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link automatedInsuranceProviderAbi}__ and `functionName` set to `"supportedTokens"`
 */
export const useReadAutomatedInsuranceProviderSupportedTokens =
  /*#__PURE__*/ createUseReadContract({
    abi: automatedInsuranceProviderAbi,
    functionName: 'supportedTokens',
  })

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link automatedInsuranceProviderAbi}__ and `functionName` set to `"USDC"`
 */
export const useReadAutomatedInsuranceProviderUsdc =
  /*#__PURE__*/ createUseReadContract({
    abi: automatedInsuranceProviderAbi,
    functionName: 'USDC',
  })

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link automatedInsuranceProviderAbi}__ and `functionName` set to `"DAI"`
 */
export const useReadAutomatedInsuranceProviderDai =
  /*#__PURE__*/ createUseReadContract({
    abi: automatedInsuranceProviderAbi,
    functionName: 'DAI',
  })

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link automatedInsuranceProviderAbi}__ and `functionName` set to `"USDT"`
 */
export const useReadAutomatedInsuranceProviderUsdt =
  /*#__PURE__*/ createUseReadContract({
    abi: automatedInsuranceProviderAbi,
    functionName: 'USDT',
  })

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link automatedInsuranceProviderAbi}__ and `functionName` set to `"premiumInfo"`
 */
export const useReadAutomatedInsuranceProviderPremiumInfo =
  /*#__PURE__*/ createUseReadContract({
    abi: automatedInsuranceProviderAbi,
    functionName: 'premiumInfo',
  })

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link automatedInsuranceProviderAbi}__ and `functionName` set to `"getActiveContractsCount"`
 */
export const useReadAutomatedInsuranceProviderGetActiveContractsCount =
  /*#__PURE__*/ createUseReadContract({
    abi: automatedInsuranceProviderAbi,
    functionName: 'getActiveContractsCount',
  })

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link automatedInsuranceProviderAbi}__ and `functionName` set to `"getActiveContracts"`
 */
export const useReadAutomatedInsuranceProviderGetActiveContracts =
  /*#__PURE__*/ createUseReadContract({
    abi: automatedInsuranceProviderAbi,
    functionName: 'getActiveContracts',
  })

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link automatedInsuranceProviderAbi}__ and `functionName` set to `"getContractsByClient"`
 */
export const useReadAutomatedInsuranceProviderGetContractsByClient =
  /*#__PURE__*/ createUseReadContract({
    abi: automatedInsuranceProviderAbi,
    functionName: 'getContractsByClient',
  })

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link automatedInsuranceProviderAbi}__ and `functionName` set to `"getLatestPrice"`
 */
export const useReadAutomatedInsuranceProviderGetLatestPrice =
  /*#__PURE__*/ createUseReadContract({
    abi: automatedInsuranceProviderAbi,
    functionName: 'getLatestPrice',
  })

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link automatedInsuranceProviderAbi}__ and `functionName` set to `"getTokenAmountForUSD"`
 */
export const useReadAutomatedInsuranceProviderGetTokenAmountForUsd =
  /*#__PURE__*/ createUseReadContract({
    abi: automatedInsuranceProviderAbi,
    functionName: 'getTokenAmountForUSD',
  })

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link automatedInsuranceProviderAbi}__ and `functionName` set to `"getEASManager"`
 */
export const useReadAutomatedInsuranceProviderGetEasManager =
  /*#__PURE__*/ createUseReadContract({
    abi: automatedInsuranceProviderAbi,
    functionName: 'getEASManager',
  })

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link automatedInsuranceProviderAbi}__ and `functionName` set to `"isEASEnabled"`
 */
export const useReadAutomatedInsuranceProviderIsEasEnabled =
  /*#__PURE__*/ createUseReadContract({
    abi: automatedInsuranceProviderAbi,
    functionName: 'isEASEnabled',
  })

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link automatedInsuranceProviderAbi}__ and `functionName` set to `"PREMIUM_GRACE_PERIOD"`
 */
export const useReadAutomatedInsuranceProviderPremiumGracePeriod =
  /*#__PURE__*/ createUseReadContract({
    abi: automatedInsuranceProviderAbi,
    functionName: 'PREMIUM_GRACE_PERIOD',
  })

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link automatedInsuranceProviderAbi}__ and `functionName` set to `"MAX_CONTRACTS_PER_BATCH"`
 */
export const useReadAutomatedInsuranceProviderMaxContractsPerBatch =
  /*#__PURE__*/ createUseReadContract({
    abi: automatedInsuranceProviderAbi,
    functionName: 'MAX_CONTRACTS_PER_BATCH',
  })

/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link automatedInsuranceProviderAbi}__
 */
export const useWriteAutomatedInsuranceProvider =
  /*#__PURE__*/ createUseWriteContract({ abi: automatedInsuranceProviderAbi })

/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link automatedInsuranceProviderAbi}__ and `functionName` set to `"newContract"`
 */
export const useWriteAutomatedInsuranceProviderNewContract =
  /*#__PURE__*/ createUseWriteContract({
    abi: automatedInsuranceProviderAbi,
    functionName: 'newContract',
  })

/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link automatedInsuranceProviderAbi}__ and `functionName` set to `"payPremium"`
 */
export const useWriteAutomatedInsuranceProviderPayPremium =
  /*#__PURE__*/ createUseWriteContract({
    abi: automatedInsuranceProviderAbi,
    functionName: 'payPremium',
  })

/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link automatedInsuranceProviderAbi}__ and `functionName` set to `"refundPremium"`
 */
export const useWriteAutomatedInsuranceProviderRefundPremium =
  /*#__PURE__*/ createUseWriteContract({
    abi: automatedInsuranceProviderAbi,
    functionName: 'refundPremium',
  })

/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link automatedInsuranceProviderAbi}__ and `functionName` set to `"claimPremium"`
 */
export const useWriteAutomatedInsuranceProviderClaimPremium =
  /*#__PURE__*/ createUseWriteContract({
    abi: automatedInsuranceProviderAbi,
    functionName: 'claimPremium',
  })

/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link automatedInsuranceProviderAbi}__ and `functionName` set to `"setAutomationEnabled"`
 */
export const useWriteAutomatedInsuranceProviderSetAutomationEnabled =
  /*#__PURE__*/ createUseWriteContract({
    abi: automatedInsuranceProviderAbi,
    functionName: 'setAutomationEnabled',
  })

/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link automatedInsuranceProviderAbi}__ and `functionName` set to `"setUpkeepInterval"`
 */
export const useWriteAutomatedInsuranceProviderSetUpkeepInterval =
  /*#__PURE__*/ createUseWriteContract({
    abi: automatedInsuranceProviderAbi,
    functionName: 'setUpkeepInterval',
  })

/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link automatedInsuranceProviderAbi}__ and `functionName` set to `"manualWeatherUpdate"`
 */
export const useWriteAutomatedInsuranceProviderManualWeatherUpdate =
  /*#__PURE__*/ createUseWriteContract({
    abi: automatedInsuranceProviderAbi,
    functionName: 'manualWeatherUpdate',
  })

/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link automatedInsuranceProviderAbi}__ and `functionName` set to `"addSupportedToken"`
 */
export const useWriteAutomatedInsuranceProviderAddSupportedToken =
  /*#__PURE__*/ createUseWriteContract({
    abi: automatedInsuranceProviderAbi,
    functionName: 'addSupportedToken',
  })

/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link automatedInsuranceProviderAbi}__
 */
export const useSimulateAutomatedInsuranceProvider =
  /*#__PURE__*/ createUseSimulateContract({
    abi: automatedInsuranceProviderAbi,
  })

/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link automatedInsuranceProviderAbi}__ and `functionName` set to `"newContract"`
 */
export const useSimulateAutomatedInsuranceProviderNewContract =
  /*#__PURE__*/ createUseSimulateContract({
    abi: automatedInsuranceProviderAbi,
    functionName: 'newContract',
  })

/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link automatedInsuranceProviderAbi}__ and `functionName` set to `"payPremium"`
 */
export const useSimulateAutomatedInsuranceProviderPayPremium =
  /*#__PURE__*/ createUseSimulateContract({
    abi: automatedInsuranceProviderAbi,
    functionName: 'payPremium',
  })

/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link automatedInsuranceProviderAbi}__ and `functionName` set to `"refundPremium"`
 */
export const useSimulateAutomatedInsuranceProviderRefundPremium =
  /*#__PURE__*/ createUseSimulateContract({
    abi: automatedInsuranceProviderAbi,
    functionName: 'refundPremium',
  })

/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link automatedInsuranceProviderAbi}__ and `functionName` set to `"claimPremium"`
 */
export const useSimulateAutomatedInsuranceProviderClaimPremium =
  /*#__PURE__*/ createUseSimulateContract({
    abi: automatedInsuranceProviderAbi,
    functionName: 'claimPremium',
  })

/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link automatedInsuranceProviderAbi}__ and `functionName` set to `"setAutomationEnabled"`
 */
export const useSimulateAutomatedInsuranceProviderSetAutomationEnabled =
  /*#__PURE__*/ createUseSimulateContract({
    abi: automatedInsuranceProviderAbi,
    functionName: 'setAutomationEnabled',
  })

/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link automatedInsuranceProviderAbi}__ and `functionName` set to `"setUpkeepInterval"`
 */
export const useSimulateAutomatedInsuranceProviderSetUpkeepInterval =
  /*#__PURE__*/ createUseSimulateContract({
    abi: automatedInsuranceProviderAbi,
    functionName: 'setUpkeepInterval',
  })

/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link automatedInsuranceProviderAbi}__ and `functionName` set to `"manualWeatherUpdate"`
 */
export const useSimulateAutomatedInsuranceProviderManualWeatherUpdate =
  /*#__PURE__*/ createUseSimulateContract({
    abi: automatedInsuranceProviderAbi,
    functionName: 'manualWeatherUpdate',
  })

/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link automatedInsuranceProviderAbi}__ and `functionName` set to `"addSupportedToken"`
 */
export const useSimulateAutomatedInsuranceProviderAddSupportedToken =
  /*#__PURE__*/ createUseSimulateContract({
    abi: automatedInsuranceProviderAbi,
    functionName: 'addSupportedToken',
  })

/**
 * Wraps __{@link useWatchContractEvent}__ with `abi` set to __{@link automatedInsuranceProviderAbi}__
 */
export const useWatchAutomatedInsuranceProviderEvent =
  /*#__PURE__*/ createUseWatchContractEvent({
    abi: automatedInsuranceProviderAbi,
  })

/**
 * Wraps __{@link useWatchContractEvent}__ with `abi` set to __{@link automatedInsuranceProviderAbi}__ and `eventName` set to `"ContractCreated"`
 */
export const useWatchAutomatedInsuranceProviderContractCreatedEvent =
  /*#__PURE__*/ createUseWatchContractEvent({
    abi: automatedInsuranceProviderAbi,
    eventName: 'ContractCreated',
  })

/**
 * Wraps __{@link useWatchContractEvent}__ with `abi` set to __{@link automatedInsuranceProviderAbi}__ and `eventName` set to `"PremiumPaid"`
 */
export const useWatchAutomatedInsuranceProviderPremiumPaidEvent =
  /*#__PURE__*/ createUseWatchContractEvent({
    abi: automatedInsuranceProviderAbi,
    eventName: 'PremiumPaid',
  })

/**
 * Wraps __{@link useWatchContractEvent}__ with `abi` set to __{@link automatedInsuranceProviderAbi}__ and `eventName` set to `"ContractStateChanged"`
 */
export const useWatchAutomatedInsuranceProviderContractStateChangedEvent =
  /*#__PURE__*/ createUseWatchContractEvent({
    abi: automatedInsuranceProviderAbi,
    eventName: 'ContractStateChanged',
  })

/**
 * Wraps __{@link useWatchContractEvent}__ with `abi` set to __{@link automatedInsuranceProviderAbi}__ and `eventName` set to `"PremiumRefunded"`
 */
export const useWatchAutomatedInsuranceProviderPremiumRefundedEvent =
  /*#__PURE__*/ createUseWatchContractEvent({
    abi: automatedInsuranceProviderAbi,
    eventName: 'PremiumRefunded',
  })

/**
 * Wraps __{@link useWatchContractEvent}__ with `abi` set to __{@link automatedInsuranceProviderAbi}__ and `eventName` set to `"PremiumClaimed"`
 */
export const useWatchAutomatedInsuranceProviderPremiumClaimedEvent =
  /*#__PURE__*/ createUseWatchContractEvent({
    abi: automatedInsuranceProviderAbi,
    eventName: 'PremiumClaimed',
  })

/**
 * Wraps __{@link useWatchContractEvent}__ with `abi` set to __{@link automatedInsuranceProviderAbi}__ and `eventName` set to `"AutomationUpkeepPerformed"`
 */
export const useWatchAutomatedInsuranceProviderAutomationUpkeepPerformedEvent =
  /*#__PURE__*/ createUseWatchContractEvent({
    abi: automatedInsuranceProviderAbi,
    eventName: 'AutomationUpkeepPerformed',
  })

/**
 * Wraps __{@link useWatchContractEvent}__ with `abi` set to __{@link automatedInsuranceProviderAbi}__ and `eventName` set to `"AttestationCreated"`
 */
export const useWatchAutomatedInsuranceProviderAttestationCreatedEvent =
  /*#__PURE__*/ createUseWatchContractEvent({
    abi: automatedInsuranceProviderAbi,
    eventName: 'AttestationCreated',
  })
