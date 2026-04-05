'use client'

import { useReadContracts } from 'wagmi'
import { type Address } from 'viem'
import { automatedInsuranceContractAbi } from '@/abi/AutomatedInsuranceContract'

export interface PolicyDetail {
  client: Address
  cropLocation: string
  premium: bigint
  payoutValue: bigint
  duration: bigint
  startDate: bigint
  activatedAt: bigint
  lastWeatherCheck: bigint
  paymentToken: Address
  currentRainfall: bigint
  daysWithoutRain: bigint
  contractActive: boolean
  premiumPaid: boolean
  contractPaid: boolean
  requestCount: bigint
  isActive: boolean
  balance: bigint
}

const fields = [
  'client', 'cropLocation', 'premium', 'payoutValue', 'duration',
  'startDate', 'activatedAt', 'lastWeatherCheck', 'paymentToken',
  'currentRainfall', 'daysWithoutRain', 'contractActive', 'premiumPaid',
  'contractPaid', 'requestCount', 'isActive', 'getContractBalance',
] as const

export function usePolicyDetail(contractAddress: Address) {
  const { data, isLoading, error } = useReadContracts({
    contracts: fields.map((name) => ({
      address: contractAddress,
      abi: automatedInsuranceContractAbi,
      functionName: name,
    })),
    query: { enabled: !!contractAddress },
  })

  const get = (idx: number) => data?.[idx]?.result

  const policy: PolicyDetail | null = data ? {
    client: (get(0) as Address) || '0x0000000000000000000000000000000000000000',
    cropLocation: (get(1) as string) || '',
    premium: (get(2) as bigint) || 0n,
    payoutValue: (get(3) as bigint) || 0n,
    duration: (get(4) as bigint) || 0n,
    startDate: (get(5) as bigint) || 0n,
    activatedAt: (get(6) as bigint) || 0n,
    lastWeatherCheck: (get(7) as bigint) || 0n,
    paymentToken: (get(8) as Address) || '0x0000000000000000000000000000000000000000',
    currentRainfall: (get(9) as bigint) || 0n,
    daysWithoutRain: (get(10) as bigint) || 0n,
    contractActive: (get(11) as boolean) || false,
    premiumPaid: (get(12) as boolean) || false,
    contractPaid: (get(13) as boolean) || false,
    requestCount: (get(14) as bigint) || 0n,
    isActive: (get(15) as boolean) || false,
    balance: (get(16) as bigint) || 0n,
  } : null

  return { policy, isLoading, error }
}
