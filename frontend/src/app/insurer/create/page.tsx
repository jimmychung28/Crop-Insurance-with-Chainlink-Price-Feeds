'use client'

import { useState } from 'react'
import Link from 'next/link'
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi'
import { parseEther, type Address, erc20Abi } from 'viem'
import { automatedInsuranceProviderAbi } from '@/abi/AutomatedInsuranceProvider'
import { CONTRACTS, TOKENS } from '@/config/contracts'

export default function CreatePolicy() {
  const { isConnected } = useAccount()
  const [clientAddress, setClientAddress] = useState('')
  const [durationDays, setDurationDays] = useState('30')
  const [premiumUSD, setPremiumUSD] = useState('100')
  const [payoutUSD, setPayoutUSD] = useState('1000')
  const [cropLocation, setCropLocation] = useState('')
  const [paymentToken, setPaymentToken] = useState('ETH')

  const { data: ethPrice } = useReadContract({
    address: CONTRACTS.provider,
    abi: automatedInsuranceProviderAbi,
    functionName: 'getLatestPrice',
  })

  const { writeContract, data: txHash, isPending } = useWriteContract()
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash: txHash })

  const premiumAmount = BigInt(Math.floor(Number(premiumUSD) * 1e8))
  const payoutAmount = BigInt(Math.floor(Number(payoutUSD) * 1e8))
  const durationSeconds = BigInt(Number(durationDays) * 86400)
  const selectedToken = TOKENS[paymentToken]
  const isEth = paymentToken === 'ETH'

  const fundingEth = ethPrice && payoutAmount > 0n
    ? (payoutAmount * BigInt(1e18) * 105n) / (BigInt(ethPrice.toString()) * 100n) // +5% buffer
    : 0n

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    if (!clientAddress || !cropLocation) return

    writeContract({
      address: CONTRACTS.provider,
      abi: automatedInsuranceProviderAbi,
      functionName: 'newContract',
      args: [
        clientAddress as Address,
        durationSeconds,
        premiumAmount,
        payoutAmount,
        cropLocation,
        selectedToken.address,
      ],
      value: isEth ? fundingEth : 0n,
    })
  }

  if (!isConnected) {
    return (
      <div className="mx-auto max-w-2xl px-4 py-16 text-center text-gray-600">
        Connect your wallet to create policies.
      </div>
    )
  }

  if (isSuccess) {
    return (
      <div className="mx-auto max-w-2xl px-4 py-16 text-center">
        <div className="rounded-lg bg-green-50 p-8">
          <h2 className="text-xl font-bold text-green-800">Policy Created!</h2>
          <p className="mt-2 text-sm text-green-600">The insurance contract has been deployed.</p>
          {txHash && <p className="mt-4 text-xs text-gray-500 font-mono">{txHash}</p>}
          <Link
            href="/insurer"
            className="mt-6 inline-block rounded-md bg-green-600 px-4 py-2 text-sm font-semibold text-white hover:bg-green-500"
          >
            Back to Dashboard
          </Link>
        </div>
      </div>
    )
  }

  return (
    <div className="mx-auto max-w-2xl px-4 py-8 sm:px-6 lg:px-8">
      <div className="mb-6">
        <Link href="/insurer" className="text-sm text-green-600 hover:text-green-500">&larr; Back</Link>
      </div>

      <h1 className="text-2xl font-bold text-gray-900">Create Insurance Policy</h1>

      <form onSubmit={handleSubmit} className="mt-6 space-y-6 rounded-lg border border-gray-200 bg-white p-6">
        <div>
          <label className="block text-sm font-medium text-gray-700">Client Address (Farmer)</label>
          <input
            type="text"
            value={clientAddress}
            onChange={(e) => setClientAddress(e.target.value)}
            placeholder="0x..."
            className="mt-1 block w-full rounded-md border border-gray-300 px-3 py-2 text-sm shadow-sm focus:border-green-500 focus:ring-green-500"
            required
          />
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700">Crop Location</label>
          <input
            type="text"
            value={cropLocation}
            onChange={(e) => setCropLocation(e.target.value)}
            placeholder="London,UK"
            className="mt-1 block w-full rounded-md border border-gray-300 px-3 py-2 text-sm shadow-sm focus:border-green-500 focus:ring-green-500"
            required
          />
        </div>

        <div className="grid grid-cols-2 gap-4">
          <div>
            <label className="block text-sm font-medium text-gray-700">Duration (days)</label>
            <input
              type="number"
              value={durationDays}
              onChange={(e) => setDurationDays(e.target.value)}
              min="1"
              className="mt-1 block w-full rounded-md border border-gray-300 px-3 py-2 text-sm shadow-sm focus:border-green-500 focus:ring-green-500"
              required
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700">Payment Token</label>
            <select
              value={paymentToken}
              onChange={(e) => setPaymentToken(e.target.value)}
              className="mt-1 block w-full rounded-md border border-gray-300 px-3 py-2 text-sm shadow-sm focus:border-green-500 focus:ring-green-500"
            >
              {Object.keys(TOKENS).map((t) => (
                <option key={t} value={t}>{t}</option>
              ))}
            </select>
          </div>
        </div>

        <div className="grid grid-cols-2 gap-4">
          <div>
            <label className="block text-sm font-medium text-gray-700">Premium (USD)</label>
            <input
              type="number"
              value={premiumUSD}
              onChange={(e) => setPremiumUSD(e.target.value)}
              min="1"
              className="mt-1 block w-full rounded-md border border-gray-300 px-3 py-2 text-sm shadow-sm focus:border-green-500 focus:ring-green-500"
              required
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700">Payout Value (USD)</label>
            <input
              type="number"
              value={payoutUSD}
              onChange={(e) => setPayoutUSD(e.target.value)}
              min="1"
              className="mt-1 block w-full rounded-md border border-gray-300 px-3 py-2 text-sm shadow-sm focus:border-green-500 focus:ring-green-500"
              required
            />
          </div>
        </div>

        {isEth && fundingEth > 0n && (
          <div className="rounded-md bg-yellow-50 p-3 text-sm text-yellow-700">
            This will require ~{(Number(fundingEth) / 1e18).toFixed(4)} ETH to fund the payout (+5% buffer).
            Gas cost: ~3-5M gas for contract deployment.
          </div>
        )}

        <button
          type="submit"
          disabled={isPending || isConfirming}
          className="w-full rounded-md bg-green-600 px-4 py-2.5 text-sm font-semibold text-white shadow hover:bg-green-500 disabled:opacity-50"
        >
          {isPending ? 'Submitting...' : isConfirming ? 'Deploying contract...' : 'Create Policy'}
        </button>
      </form>
    </div>
  )
}
