'use client'

import { use } from 'react'
import Link from 'next/link'
import { type Address } from 'viem'
import { usePolicyDetail } from '@/hooks/usePolicyDetail'
import { formatUSD, formatRainfall, formatDuration, formatTimestamp, formatAddress, getPolicyStatus, getStatusColor } from '@/lib/format'
import { getTokenByAddress } from '@/config/contracts'

export default function PolicyDetailPage({ params }: { params: Promise<{ address: string }> }) {
  const { address } = use(params)
  const contractAddress = address as Address
  const { policy, isLoading, error } = usePolicyDetail(contractAddress)

  if (isLoading) {
    return (
      <div className="mx-auto max-w-4xl px-4 py-8 text-center text-gray-500">
        Loading policy...
      </div>
    )
  }

  if (error || !policy) {
    return (
      <div className="mx-auto max-w-4xl px-4 py-8">
        <div className="rounded-md bg-red-50 p-4 text-sm text-red-700">
          Failed to load policy at {formatAddress(address)}.
        </div>
      </div>
    )
  }

  const status = getPolicyStatus(policy.contractActive, policy.premiumPaid, policy.contractPaid)
  const statusColor = getStatusColor(status)
  const token = getTokenByAddress(policy.paymentToken)
  const droughtProgress = Math.min(Number(policy.daysWithoutRain), 3)

  const endDate = policy.activatedAt > 0n
    ? policy.activatedAt + policy.duration
    : policy.startDate + policy.duration
  const now = BigInt(Math.floor(Date.now() / 1000))
  const timeRemaining = endDate > now ? endDate - now : 0n
  const totalDuration = Number(policy.duration)
  const elapsed = totalDuration - Number(timeRemaining)
  const progressPercent = totalDuration > 0 ? Math.min(100, (elapsed / totalDuration) * 100) : 0

  return (
    <div className="mx-auto max-w-4xl px-4 py-8 sm:px-6 lg:px-8">
      <div className="mb-6">
        <Link href="/farmer" className="text-sm text-green-600 hover:text-green-500">&larr; Back to My Policies</Link>
      </div>

      <div className="flex items-start justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">{policy.cropLocation}</h1>
          <p className="mt-1 text-sm text-gray-500 font-mono">{address}</p>
        </div>
        <span className={`inline-flex items-center rounded-full px-3 py-1 text-sm font-medium ${statusColor}`}>
          {status.replace('_', ' ')}
        </span>
      </div>

      {/* Policy Info */}
      <div className="mt-6 rounded-lg border border-gray-200 bg-white p-6">
        <h2 className="text-lg font-semibold text-gray-900">Policy Info</h2>
        <dl className="mt-4 grid grid-cols-2 gap-4 sm:grid-cols-4">
          <div>
            <dt className="text-sm text-gray-500">Premium</dt>
            <dd className="font-medium text-gray-900">{formatUSD(policy.premium)}</dd>
          </div>
          <div>
            <dt className="text-sm text-gray-500">Coverage</dt>
            <dd className="font-medium text-gray-900">{formatUSD(policy.payoutValue)}</dd>
          </div>
          <div>
            <dt className="text-sm text-gray-500">Payment Token</dt>
            <dd className="font-medium text-gray-900">{token.symbol}</dd>
          </div>
          <div>
            <dt className="text-sm text-gray-500">Duration</dt>
            <dd className="font-medium text-gray-900">{formatDuration(policy.duration)}</dd>
          </div>
          <div>
            <dt className="text-sm text-gray-500">Activated</dt>
            <dd className="font-medium text-gray-900">{formatTimestamp(policy.activatedAt)}</dd>
          </div>
          <div>
            <dt className="text-sm text-gray-500">Client</dt>
            <dd className="font-medium text-gray-900">{formatAddress(policy.client)}</dd>
          </div>
          <div>
            <dt className="text-sm text-gray-500">Oracle Checks</dt>
            <dd className="font-medium text-gray-900">{policy.requestCount.toString()}</dd>
          </div>
          <div>
            <dt className="text-sm text-gray-500">Last Check</dt>
            <dd className="font-medium text-gray-900">{formatTimestamp(policy.lastWeatherCheck)}</dd>
          </div>
        </dl>
      </div>

      {/* Timeline */}
      {policy.activatedAt > 0n && (
        <div className="mt-6 rounded-lg border border-gray-200 bg-white p-6">
          <h2 className="text-lg font-semibold text-gray-900">Timeline</h2>
          <div className="mt-4">
            <div className="flex justify-between text-sm text-gray-500">
              <span>{formatTimestamp(policy.activatedAt)}</span>
              <span>{timeRemaining > 0n ? `${formatDuration(timeRemaining)} remaining` : 'Expired'}</span>
            </div>
            <div className="mt-2 h-3 rounded-full bg-gray-200">
              <div
                className="h-3 rounded-full bg-green-500 transition-all"
                style={{ width: `${progressPercent}%` }}
              />
            </div>
          </div>
        </div>
      )}

      {/* Weather Panel */}
      <div className="mt-6 rounded-lg border border-gray-200 bg-white p-6">
        <h2 className="text-lg font-semibold text-gray-900">Weather Status</h2>
        <div className="mt-4 grid grid-cols-2 gap-6">
          <div>
            <p className="text-sm text-gray-500">Current Rainfall</p>
            <p className="text-3xl font-bold text-gray-900">{formatRainfall(policy.currentRainfall)}</p>
          </div>
          <div>
            <p className="text-sm text-gray-500">Drought Counter</p>
            <div className="mt-2 flex items-center gap-3">
              <div className="flex gap-1">
                {[0, 1, 2].map((i) => (
                  <div
                    key={i}
                    className={`h-8 w-8 rounded ${
                      i < droughtProgress ? 'bg-red-500' : 'bg-gray-200'
                    }`}
                  />
                ))}
              </div>
              <span className="text-2xl font-bold text-gray-900">{droughtProgress}/3</span>
            </div>
            {droughtProgress >= 3 && (
              <p className="mt-2 text-sm font-medium text-red-600">Drought threshold reached — payout triggered</p>
            )}
          </div>
        </div>
      </div>

      {/* Actions */}
      {status === 'pending' && (
        <div className="mt-6">
          <Link
            href={`/farmer/pay/${address}`}
            className="inline-flex items-center rounded-md bg-green-600 px-4 py-2 text-sm font-semibold text-white shadow hover:bg-green-500"
          >
            Pay Premium
          </Link>
        </div>
      )}
    </div>
  )
}
