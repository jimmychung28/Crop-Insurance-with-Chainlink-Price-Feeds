export const easAbi = [
  {
    type: 'function', name: 'getAttestation', inputs: [{ name: 'uid', type: 'bytes32' }],
    outputs: [{
      type: 'tuple',
      components: [
        { name: 'uid', type: 'bytes32' },
        { name: 'schema', type: 'bytes32' },
        { name: 'time', type: 'uint64' },
        { name: 'expirationTime', type: 'uint64' },
        { name: 'revocationTime', type: 'uint64' },
        { name: 'refUID', type: 'bytes32' },
        { name: 'recipient', type: 'address' },
        { name: 'attester', type: 'address' },
        { name: 'revocable', type: 'bool' },
        { name: 'data', type: 'bytes' },
      ],
    }],
    stateMutability: 'view',
  },
] as const
