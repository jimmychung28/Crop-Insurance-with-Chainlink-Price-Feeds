export const easInsuranceManagerAbi = [
  { type: 'function', name: 'getAttestationStats', inputs: [], outputs: [{ name: 'totalPolicies', type: 'uint256' }, { name: 'totalWeather', type: 'uint256' }, { name: 'totalClaims', type: 'uint256' }, { name: 'totalCompliance', type: 'uint256' }, { name: 'totalPremiums', type: 'uint256' }], stateMutability: 'view' },
  { type: 'function', name: 'getPolicyAttestations', inputs: [{ name: 'policyContract', type: 'address' }], outputs: [{ type: 'bytes32[]' }], stateMutability: 'view' },
  { type: 'function', name: 'getWeatherAttestations', inputs: [{ name: 'location', type: 'string' }], outputs: [{ type: 'bytes32[]' }], stateMutability: 'view' },
  { type: 'function', name: 'getClientAttestations', inputs: [{ name: 'client', type: 'address' }], outputs: [{ type: 'bytes32[]' }], stateMutability: 'view' },
  { type: 'function', name: 'getPremiumAttestations', inputs: [{ name: 'policyContract', type: 'address' }], outputs: [{ type: 'bytes32[]' }], stateMutability: 'view' },
  { type: 'function', name: 'verifyPolicyAttestation', inputs: [{ name: 'uid', type: 'bytes32' }], outputs: [{ type: 'bool' }], stateMutability: 'view' },
  { type: 'function', name: 'verifyWeatherAttestation', inputs: [{ name: 'uid', type: 'bytes32' }], outputs: [{ type: 'bool' }], stateMutability: 'view' },
  { type: 'function', name: 'verifyClaimAttestation', inputs: [{ name: 'uid', type: 'bytes32' }], outputs: [{ type: 'bool' }], stateMutability: 'view' },
  { type: 'function', name: 'isValidAttestation', inputs: [{ name: 'uid', type: 'bytes32' }], outputs: [{ type: 'bool' }], stateMutability: 'view' },
  { type: 'function', name: 'getLatestWeatherAttestation', inputs: [{ name: 'location', type: 'string' }], outputs: [{ type: 'bytes32' }], stateMutability: 'view' },
  { type: 'function', name: 'getLatestPolicyAttestation', inputs: [{ name: 'policyContract', type: 'address' }], outputs: [{ type: 'bytes32' }], stateMutability: 'view' },
] as const
