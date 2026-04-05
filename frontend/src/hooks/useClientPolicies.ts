'use client'

import { useReadContract, useReadContracts } from 'wagmi'
import { type Address } from 'viem'
import { automatedInsuranceProviderAbi } from '@/abi/AutomatedInsuranceProvider'
import { automatedInsuranceContractAbi } from '@/abi/AutomatedInsuranceContract'
import { CONTRACTS } from '@/config/contracts'

export interface PolicySummary {
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
  duration: bigint
  activatedAt: bigint
}

export function useClientPolicies(clientAddress: Address | undefined) {
  const { data: contractAddresses, isLoading: isLoadingAddresses, error: addressError } = useReadContract({
    address: CONTRACTS.provider,
    abi: automatedInsuranceProviderAbi,
    functionName: 'getContractsByClient',
    args: clientAddress ? [clientAddress] : undefined,
    query: { enabled: !!clientAddress && CONTRACTS.provider !== '0x0000000000000000000000000000000000000000' },
  })

  const contracts = (contractAddresses || []) as Address[]

  const { data: policyData, isLoading: isLoadingPolicies } = useReadContracts({
    contracts: contracts.flatMap((addr) => [
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
      { address: addr, abi: automatedInsuranceContractAbi, functionName: 'duration' },
      { address: addr, abi: automatedInsuranceContractAbi, functionName: 'activatedAt' },
    ]),
    query: { enabled: contracts.length > 0 },
  })

  const FIELDS_PER_CONTRACT = 12

  const policies: PolicySummary[] = contracts.map((addr, i) => {
    const offset = i * FIELDS_PER_CONTRACT
    const get = (idx: number) => policyData?.[offset + idx]?.result

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
      duration: (get(10) as bigint) || 0n,
      activatedAt: (get(11) as bigint) || 0n,
    }
  })

  return {
    policies: policyData ? policies : [],
    contractAddresses: contracts,
    isLoading: isLoadingAddresses || isLoadingPolicies,
    error: addressError,
  }
}
