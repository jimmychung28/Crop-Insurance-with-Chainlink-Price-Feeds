'use client'

import { use } from 'react'
import Link from 'next/link'
import { type Address, formatEther } from 'viem'
import { useAccount } from 'wagmi'
import { usePremiumPayment } from '@/hooks/usePremiumPayment'
import { formatUSD, formatTimestamp, gracePeriodRemaining } from '@/lib/format'
import { getTokenByAddress, CONTRACTS } from '@/config/contracts'
import { useReadContract } from 'wagmi'
import { automatedInsuranceProviderAbi } from '@/abi/AutomatedInsuranceProvider'

export default function PayPremiumPage({ params }: { params: Promise<{ address: string }> }) {
  const { address } = use(params)
  const contractAddress = address as Address
  const { isConnected } = useAccount()

  const {
    premiumInfo, paymentToken, isEthPayment,
    ethAmount, tokenAmount, needsApproval,
    handleApprove, handlePay,
    isApproving, isApproveConfirmed,
    isPaying, isPayConfirmed,
    payTxHash,
  } = usePremiumPayment(contractAddress)

  const { data: gracePeriod } = useReadContract({
    address: CONTRACTS.provider,
    abi: automatedInsuranceProviderAbi,
    functionName: 'PREMIUM_GRACE_PERIOD',
  })

  if (!isConnected) {
    return (
      <div className="mx-auto max-w-2xl px-4 py-16 text-center">
        <p className="text-gray-600">Connect your wallet to pay premium.</p>
      </div>
    )
  }

  if (isPayConfirmed) {
    return (
      <div className="mx-auto max-w-2xl px-4 py-16 text-center">
        <div className="rounded-lg bg-green-50 p-8">
          <h2 className="text-xl font-bold text-green-800">Premium Paid Successfully!</h2>
          <p className="mt-2 text-sm text-green-600">Your policy is now active.</p>
          {payTxHash && (
            <p className="mt-4 text-xs text-gray-500 font-mono">{payTxHash}</p>
          )}
          <Link
            href={`/farmer/policy/${address}`}
            className="mt-6 inline-block rounded-md bg-green-600 px-4 py-2 text-sm font-semibold text-white hover:bg-green-500"
          >
            View Policy
          </Link>
        </div>
      </div>
    )
  }

  const isPaid = premiumInfo?.[5] // paid field
  const createdAt = premiumInfo?.[3] || 0n // createdAt field
  const premiumAmount = premiumInfo?.[0] || 0n

  const remaining = gracePeriod ? gracePeriodRemaining(createdAt, gracePeriod) : 0
  const isExpired = remaining <= 0 && createdAt > 0n
  const token = paymentToken ? getTokenByAddress(paymentToken) : null

  return (
    <div className="mx-auto max-w-2xl px-4 py-8 sm:px-6 lg:px-8">
      <div className="mb-6">
        <Link href="/farmer" className="text-sm text-green-600 hover:text-green-500">&larr; Back</Link>
      </div>

      <h1 className="text-2xl font-bold text-gray-900">Pay Premium</h1>

      <div className="mt-6 rounded-lg border border-gray-200 bg-white p-6">
        {isPaid && (
          <div className="rounded-md bg-yellow-50 p-4 text-sm text-yellow-700 mb-4">
            Premium already paid for this policy.
          </div>
        )}

        {isExpired && !isPaid && (
          <div className="rounded-md bg-red-50 p-4 text-sm text-red-700 mb-4">
            Grace period has expired. This premium can no longer be paid.
          </div>
        )}

        <dl className="space-y-4">
          <div className="flex justify-between">
            <dt className="text-sm text-gray-500">Premium (USD)</dt>
            <dd className="font-medium text-gray-900">{formatUSD(premiumAmount)}</dd>
          </div>
          <div className="flex justify-between">
            <dt className="text-sm text-gray-500">Payment Token</dt>
            <dd className="font-medium text-gray-900">{token?.symbol || 'Loading...'}</dd>
          </div>
          {isEthPayment && ethAmount > 0n && (
            <div className="flex justify-between">
              <dt className="text-sm text-gray-500">Amount (ETH, +3% buffer)</dt>
              <dd className="font-medium text-gray-900">{formatEther(ethAmount)} ETH</dd>
            </div>
          )}
          {!isEthPayment && tokenAmount && (
            <div className="flex justify-between">
              <dt className="text-sm text-gray-500">Amount ({token?.symbol})</dt>
              <dd className="font-medium text-gray-900">{tokenAmount.toString()}</dd>
            </div>
          )}
          <div className="flex justify-between">
            <dt className="text-sm text-gray-500">Created</dt>
            <dd className="font-medium text-gray-900">{formatTimestamp(createdAt)}</dd>
          </div>
          {!isExpired && remaining > 0 && (
            <div className="flex justify-between">
              <dt className="text-sm text-gray-500">Time Remaining</dt>
              <dd className={`font-medium ${remaining < 3600 ? 'text-red-600' : 'text-gray-900'}`}>
                {Math.floor(remaining / 3600)}h {Math.floor((remaining % 3600) / 60)}m
              </dd>
            </div>
          )}
        </dl>

        {!isPaid && !isExpired && (
          <div className="mt-6 space-y-3">
            {needsApproval && !isApproveConfirmed && (
              <button
                onClick={handleApprove}
                disabled={isApproving}
                className="w-full rounded-md bg-blue-600 px-4 py-2.5 text-sm font-semibold text-white shadow hover:bg-blue-500 disabled:opacity-50"
              >
                {isApproving ? 'Approving...' : `Approve ${token?.symbol}`}
              </button>
            )}
            <button
              onClick={handlePay}
              disabled={isPaying || (!!needsApproval && !isApproveConfirmed)}
              className="w-full rounded-md bg-green-600 px-4 py-2.5 text-sm font-semibold text-white shadow hover:bg-green-500 disabled:opacity-50"
            >
              {isPaying ? 'Paying...' : 'Pay Premium'}
            </button>
          </div>
        )}
      </div>
    </div>
  )
}
