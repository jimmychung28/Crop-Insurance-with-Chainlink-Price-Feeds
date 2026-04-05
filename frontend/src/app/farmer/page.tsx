'use client'

import Link from 'next/link'
import { useAccount } from 'wagmi'
import { ConnectKitButton } from 'connectkit'
import { useClientPolicies, type PolicySummary } from '@/hooks/useClientPolicies'
import { formatUSD, formatRainfall, getPolicyStatus, getStatusColor } from '@/lib/format'
import { getTokenByAddress } from '@/config/contracts'
import { formatAddress } from '@/lib/format'

function PolicyCard({ policy }: { policy: PolicySummary }) {
  const status = getPolicyStatus(policy.contractActive, policy.premiumPaid, policy.contractPaid)
  const statusColor = getStatusColor(status)
  const token = getTokenByAddress(policy.paymentToken)
  const droughtProgress = Math.min(Number(policy.daysWithoutRain), 3)

  return (
    <div className="rounded-lg border border-gray-200 bg-white p-6 shadow-sm hover:shadow-md transition-shadow">
      <div className="flex items-start justify-between">
        <div>
          <h3 className="font-semibold text-gray-900">{policy.cropLocation || 'Unknown Location'}</h3>
          <p className="mt-1 text-sm text-gray-500">{formatAddress(policy.address)}</p>
        </div>
        <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ${statusColor}`}>
          {status.replace('_', ' ')}
        </span>
      </div>

      <div className="mt-4 grid grid-cols-2 gap-4 text-sm">
        <div>
          <p className="text-gray-500">Premium</p>
          <p className="font-medium text-gray-900">{formatUSD(policy.premium)} ({token.symbol})</p>
        </div>
        <div>
          <p className="text-gray-500">Coverage</p>
          <p className="font-medium text-gray-900">{formatUSD(policy.payoutValue)}</p>
        </div>
        <div>
          <p className="text-gray-500">Rainfall</p>
          <p className="font-medium text-gray-900">{formatRainfall(policy.currentRainfall)}</p>
        </div>
        <div>
          <p className="text-gray-500">Drought</p>
          <div className="flex items-center gap-2">
            <div className="flex gap-0.5">
              {[0, 1, 2].map((i) => (
                <div
                  key={i}
                  className={`h-4 w-4 rounded-sm ${
                    i < droughtProgress ? 'bg-red-500' : 'bg-gray-200'
                  }`}
                />
              ))}
            </div>
            <span className="text-xs text-gray-600">{droughtProgress}/3 days</span>
          </div>
        </div>
      </div>

      <div className="mt-4 flex gap-2">
        {status === 'pending' && (
          <Link
            href={`/farmer/pay/${policy.address}`}
            className="rounded-md bg-green-600 px-3 py-1.5 text-sm font-medium text-white hover:bg-green-500"
          >
            Pay Premium
          </Link>
        )}
        <Link
          href={`/farmer/policy/${policy.address}`}
          className="rounded-md bg-white px-3 py-1.5 text-sm font-medium text-gray-700 ring-1 ring-gray-300 hover:bg-gray-50"
        >
          View Details
        </Link>
      </div>
    </div>
  )
}

export default function FarmerDashboard() {
  const { address, isConnected } = useAccount()
  const { policies, isLoading, error } = useClientPolicies(address)

  if (!isConnected) {
    return (
      <div className="mx-auto max-w-4xl px-4 py-16 text-center">
        <h1 className="text-2xl font-bold text-gray-900">Farmer Dashboard</h1>
        <p className="mt-2 text-gray-600">Connect your wallet to view your policies.</p>
        <div className="mt-6 flex justify-center">
          <ConnectKitButton />
        </div>
      </div>
    )
  }

  return (
    <div className="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">My Policies</h1>
          <p className="mt-1 text-sm text-gray-600">
            {policies.length} {policies.length === 1 ? 'policy' : 'policies'} found
          </p>
        </div>
      </div>

      {isLoading && (
        <div className="mt-8 text-center text-gray-500">Loading policies...</div>
      )}

      {error && (
        <div className="mt-8 rounded-md bg-red-50 p-4 text-sm text-red-700">
          Failed to load policies. Make sure the contract is deployed and configured.
        </div>
      )}

      {!isLoading && !error && policies.length === 0 && (
        <div className="mt-8 rounded-md border-2 border-dashed border-gray-300 p-12 text-center">
          <p className="text-gray-500">No policies found for your wallet.</p>
          <p className="mt-1 text-sm text-gray-400">Ask an insurer to create a policy for you.</p>
        </div>
      )}

      {policies.length > 0 && (
        <div className="mt-6 grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
          {policies.map((policy) => (
            <PolicyCard key={policy.address} policy={policy} />
          ))}
        </div>
      )}
    </div>
  )
}
