'use client'

import { useReadContract, useReadContracts } from 'wagmi'
import { type Address } from 'viem'
import { automatedInsuranceProviderAbi } from '@/abi/AutomatedInsuranceProvider'
import { automatedInsuranceContractAbi } from '@/abi/AutomatedInsuranceContract'
import { CONTRACTS } from '@/config/contracts'

export interface ActiveContract {
  address: Address
  client: Address
  cropLocation: string
  premium: bigint
  payoutValue: bigint
  paymentToken: Address
  contractActive: boolean
  premiumPaid: boolean
  contractPaid: boolean
  currentRainfall: bigint
  daysWithoutRain: bigint
  lastWeatherCheck: bigint
  requestCount: bigint
}

export function useActiveContracts() {
  const isConfigured = CONTRACTS.provider !== '0x0000000000000000000000000000000000000000'

  const { data: count } = useReadContract({
    address: CONTRACTS.provider,
    abi: automatedInsuranceProviderAbi,
    functionName: 'getActiveContractsCount',
    query: { enabled: isConfigured },
  })

  const activeCount = Number(count || 0n)

  const { data: addresses } = useReadContract({
    address: CONTRACTS.provider,
    abi: automatedInsuranceProviderAbi,
    functionName: 'getActiveContracts',
    args: [0n, BigInt(activeCount)],
    query: { enabled: isConfigured && activeCount > 0 },
  })

  const contractAddresses = (addresses || []) as Address[]

  const { data: details, isLoading } = useReadContracts({
    contracts: contractAddresses.flatMap((addr) => [
      { address: addr, abi: automatedInsuranceContractAbi, functionName: 'client' },
      { address: addr, abi: automatedInsuranceContractAbi, functionName: 'cropLocation' },
      { address: addr, abi: automatedInsuranceContractAbi, functionName: 'premium' },
      { address: addr, abi: automatedInsuranceContractAbi, functionName: 'payoutValue' },
      { address: addr, abi: automatedInsuranceContractAbi, functionName: 'paymentToken' },
      { address: addr, abi: automatedInsuranceContractAbi, functionName: 'contractActive' },
      { address: addr, abi: automatedInsuranceContractAbi, functionName: 'premiumPaid' },
      { address: addr, abi: automatedInsuranceContractAbi, functionName: 'contractPaid' },
      { address: addr, abi: automatedInsuranceContractAbi, functionName: 'currentRainfall' },
      { address: addr, abi: automatedInsuranceContractAbi, functionName: 'daysWithoutRain' },
      { address: addr, abi: automatedInsuranceContractAbi, functionName: 'lastWeatherCheck' },
      { address: addr, abi: automatedInsuranceContractAbi, functionName: 'requestCount' },
    ]),
    query: { enabled: contractAddresses.length > 0 },
  })

  const FIELDS = 12
  const contracts: ActiveContract[] = contractAddresses.map((addr, i) => {
    const get = (idx: number) => details?.[i * FIELDS + idx]?.result
    return {
      address: addr,
      client: (get(0) as Address) || '0x0000000000000000000000000000000000000000',
      cropLocation: (get(1) as string) || '',
      premium: (get(2) as bigint) || 0n,
      payoutValue: (get(3) as bigint) || 0n,
      paymentToken: (get(4) as Address) || '0x0000000000000000000000000000000000000000',
      contractActive: (get(5) as boolean) || false,
      premiumPaid: (get(6) as boolean) || false,
      contractPaid: (get(7) as boolean) || false,
      currentRainfall: (get(8) as bigint) || 0n,
      daysWithoutRain: (get(9) as bigint) || 0n,
      lastWeatherCheck: (get(10) as bigint) || 0n,
      requestCount: (get(11) as bigint) || 0n,
    }
  })

  return {
    contracts: details ? contracts : [],
    activeCount,
    isLoading,
  }
}
