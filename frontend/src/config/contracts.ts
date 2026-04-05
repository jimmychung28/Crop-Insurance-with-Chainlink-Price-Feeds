import { type Address } from 'viem'

export const CONTRACTS = {
  provider: (process.env.NEXT_PUBLIC_PROVIDER_ADDRESS || '0x0000000000000000000000000000000000000000') as Address,
  easManager: (process.env.NEXT_PUBLIC_EAS_MANAGER_ADDRESS || '0x0000000000000000000000000000000000000000') as Address,
  eas: '0xC2679fBD37d54388Ce493F1DB75320D236e1815e' as const, // Sepolia EAS
} as const

export const TOKENS: Record<string, { address: Address; symbol: string; decimals: number }> = {
  ETH: { address: '0x0000000000000000000000000000000000000000' as Address, symbol: 'ETH', decimals: 18 },
  USDC: { address: (process.env.NEXT_PUBLIC_USDC_ADDRESS || '0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8') as Address, symbol: 'USDC', decimals: 6 },
  DAI: { address: (process.env.NEXT_PUBLIC_DAI_ADDRESS || '0xFF34B3d4Aee8ddCd6F9AFFFB6Fe49bD371b8a357') as Address, symbol: 'DAI', decimals: 18 },
}

export function getTokenByAddress(address: Address): { symbol: string; decimals: number } {
  const token = Object.values(TOKENS).find(t => t.address.toLowerCase() === address.toLowerCase())
  return token || { symbol: 'Unknown', decimals: 18 }
}
