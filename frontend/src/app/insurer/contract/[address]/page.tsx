'use client'

import { use } from 'react'
import Link from 'next/link'
import { type Address } from 'viem'
import { useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi'
import { usePolicyDetail } from '@/hooks/usePolicyDetail'
import { automatedInsuranceProviderAbi } from '@/abi/AutomatedInsuranceProvider'
import { CONTRACTS, getTokenByAddress } from '@/config/contracts'
import { formatUSD, formatRainfall, formatDuration, formatTimestamp, formatAddress, getPolicyStatus, getStatusColor } from '@/lib/format'

export default function InsurerContractDetail({ params }: { params: Promise<{ address: string }> }) {
  const { address } = use(params)
  const contractAddress = address as Address
  const { policy, isLoading, error } = usePolicyDetail(contractAddress)

  const { data: premiumInfo } = useReadContract({
    address: CONTRACTS.provider,
    abi: automatedInsuranceProviderAbi,
    functionName: 'premiumInfo',
    args: [contractAddress],
  })

  const { writeContract: claimPremium, data: claimTxHash, isPending: isClaiming } = useWriteContract()
  const { isSuccess: isClaimConfirmed } = useWaitForTransactionReceipt({ hash: claimTxHash })

  const { writeContract: manualUpdate, data: updateTxHash, isPending: isUpdating } = useWriteContract()
  const { isSuccess: isUpdateConfirmed } = useWaitForTransactionReceipt({ hash: updateTxHash })

  if (isLoading) {
    return <div className="mx-auto max-w-4xl px-4 py-8 text-center text-gray-500">Loading...</div>
  }

  if (error || !policy) {
    return (
      <div className="mx-auto max-w-4xl px-4 py-8">
        <div className="rounded-md bg-red-50 p-4 text-sm text-red-700">Failed to load contract.</div>
      </div>
    )
  }

  const status = getPolicyStatus(policy.contractActive, policy.premiumPaid, policy.contractPaid)
  const statusColor = getStatusColor(status)
  const token = getTokenByAddress(policy.paymentToken)
  const canClaimPremium = !policy.isActive && premiumInfo?.[5] // paid = true and contract not active

  return (
    <div className="mx-auto max-w-4xl px-4 py-8 sm:px-6 lg:px-8">
      <div className="mb-6">
        <Link href="/insurer" className="text-sm text-green-600 hover:text-green-500">&larr; Back to Dashboard</Link>
      </div>

      <div className="flex items-start justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">{policy.cropLocation}</h1>
          <p className="mt-1 text-sm text-gray-500 font-mono">{address}</p>
        </div>
        <span className={`inline-flex rounded-full px-3 py-1 text-sm font-medium ${statusColor}`}>
          {status.replace('_', ' ')}
        </span>
      </div>

      {/* Policy Info */}
      <div className="mt-6 rounded-lg border border-gray-200 bg-white p-6">
        <h2 className="text-lg font-semibold text-gray-900">Contract Info</h2>
        <dl className="mt-4 grid grid-cols-2 gap-4 sm:grid-cols-4">
          <div>
            <dt className="text-sm text-gray-500">Client</dt>
            <dd className="font-medium text-gray-900 font-mono">{formatAddress(policy.client)}</dd>
          </div>
          <div>
            <dt className="text-sm text-gray-500">Premium</dt>
            <dd className="font-medium text-gray-900">{formatUSD(policy.premium)} ({token.symbol})</dd>
          </div>
          <div>
            <dt className="text-sm text-gray-500">Coverage</dt>
            <dd className="font-medium text-gray-900">{formatUSD(policy.payoutValue)}</dd>
          </div>
          <div>
            <dt className="text-sm text-gray-500">Duration</dt>
            <dd className="font-medium text-gray-900">{formatDuration(policy.duration)}</dd>
          </div>
          <div>
            <dt className="text-sm text-gray-500">Premium Paid</dt>
            <dd className="font-medium text-gray-900">{policy.premiumPaid ? 'Yes' : 'No'}</dd>
          </div>
          <div>
            <dt className="text-sm text-gray-500">Oracle Checks</dt>
            <dd className="font-medium text-gray-900">{policy.requestCount.toString()}</dd>
          </div>
          <div>
            <dt className="text-sm text-gray-500">Last Check</dt>
            <dd className="font-medium text-gray-900">{formatTimestamp(policy.lastWeatherCheck)}</dd>
          </div>
          <div>
            <dt className="text-sm text-gray-500">Balance</dt>
            <dd className="font-medium text-gray-900">{policy.balance.toString()}</dd>
          </div>
        </dl>
      </div>

      {/* Weather */}
      <div className="mt-6 rounded-lg border border-gray-200 bg-white p-6">
        <h2 className="text-lg font-semibold text-gray-900">Weather Status</h2>
        <div className="mt-4 grid grid-cols-2 gap-6">
          <div>
            <p className="text-sm text-gray-500">Rainfall</p>
            <p className="text-2xl font-bold text-gray-900">{formatRainfall(policy.currentRainfall)}</p>
          </div>
          <div>
            <p className="text-sm text-gray-500">Drought</p>
            <p className="text-2xl font-bold text-gray-900">
              {Math.min(Number(policy.daysWithoutRain), 3)}/3 days
            </p>
          </div>
        </div>
      </div>

      {/* Actions */}
      <div className="mt-6 flex gap-3">
        {canClaimPremium && (
          <button
            onClick={() => claimPremium({
              address: CONTRACTS.provider,
              abi: automatedInsuranceProviderAbi,
              functionName: 'claimPremium',
              args: [contractAddress],
            })}
            disabled={isClaiming || isClaimConfirmed}
            className="rounded-md bg-blue-600 px-4 py-2 text-sm font-semibold text-white shadow hover:bg-blue-500 disabled:opacity-50"
          >
            {isClaiming ? 'Claiming...' : isClaimConfirmed ? 'Claimed!' : 'Claim Premium'}
          </button>
        )}
        {policy.isActive && (
          <button
            onClick={() => manualUpdate({
              address: CONTRACTS.provider,
              abi: automatedInsuranceProviderAbi,
              functionName: 'manualWeatherUpdate',
              args: [[contractAddress]],
            })}
            disabled={isUpdating || isUpdateConfirmed}
            className="rounded-md bg-white px-4 py-2 text-sm font-medium text-gray-700 ring-1 ring-gray-300 hover:bg-gray-50 disabled:opacity-50"
          >
            {isUpdating ? 'Updating...' : isUpdateConfirmed ? 'Updated!' : 'Manual Weather Check'}
          </button>
        )}
      </div>
    </div>
  )
}
