'use client'

import { useState } from 'react'
import Link from 'next/link'
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi'
import { automatedInsuranceProviderAbi } from '@/abi/AutomatedInsuranceProvider'
import { CONTRACTS } from '@/config/contracts'
import { formatTimestamp } from '@/lib/format'

export default function AutomationManagement() {
  const { isConnected } = useAccount()
  const [newInterval, setNewInterval] = useState('')

  const { data: automationEnabled } = useReadContract({
    address: CONTRACTS.provider,
    abi: automatedInsuranceProviderAbi,
    functionName: 'automationEnabled',
  })

  const { data: upkeepInterval } = useReadContract({
    address: CONTRACTS.provider,
    abi: automatedInsuranceProviderAbi,
    functionName: 'upkeepInterval',
  })

  const { data: lastUpkeep } = useReadContract({
    address: CONTRACTS.provider,
    abi: automatedInsuranceProviderAbi,
    functionName: 'lastUpkeepTimestamp',
  })

  const { data: batchCounter } = useReadContract({
    address: CONTRACTS.provider,
    abi: automatedInsuranceProviderAbi,
    functionName: 'upkeepBatchCounter',
  })

  const { data: activeCount } = useReadContract({
    address: CONTRACTS.provider,
    abi: automatedInsuranceProviderAbi,
    functionName: 'getActiveContractsCount',
  })

  const { writeContract: toggleAutomation, data: toggleTxHash, isPending: isToggling } = useWriteContract()
  const { isSuccess: isToggleConfirmed } = useWaitForTransactionReceipt({ hash: toggleTxHash })

  const { writeContract: setInterval_, data: intervalTxHash, isPending: isSettingInterval } = useWriteContract()
  const { isSuccess: isIntervalConfirmed } = useWaitForTransactionReceipt({ hash: intervalTxHash })

  const intervalHours = upkeepInterval ? Number(upkeepInterval) / 3600 : 0

  if (!isConnected) {
    return (
      <div className="mx-auto max-w-2xl px-4 py-16 text-center text-gray-600">
        Connect your wallet to manage automation.
      </div>
    )
  }

  return (
    <div className="mx-auto max-w-3xl px-4 py-8 sm:px-6 lg:px-8">
      <div className="mb-6">
        <Link href="/insurer" className="text-sm text-green-600 hover:text-green-500">&larr; Back to Dashboard</Link>
      </div>

      <h1 className="text-2xl font-bold text-gray-900">Chainlink Automation</h1>

      {/* Status */}
      <div className="mt-6 rounded-lg border border-gray-200 bg-white p-6">
        <h2 className="text-lg font-semibold text-gray-900">Status</h2>
        <dl className="mt-4 grid grid-cols-2 gap-4">
          <div>
            <dt className="text-sm text-gray-500">Automation</dt>
            <dd className={`text-lg font-bold ${automationEnabled ? 'text-green-600' : 'text-red-600'}`}>
              {automationEnabled ? 'Enabled' : 'Disabled'}
            </dd>
          </div>
          <div>
            <dt className="text-sm text-gray-500">Upkeep Interval</dt>
            <dd className="text-lg font-bold text-gray-900">{intervalHours}h</dd>
          </div>
          <div>
            <dt className="text-sm text-gray-500">Last Upkeep</dt>
            <dd className="font-medium text-gray-900">{lastUpkeep ? formatTimestamp(lastUpkeep) : 'Never'}</dd>
          </div>
          <div>
            <dt className="text-sm text-gray-500">Total Batches</dt>
            <dd className="text-lg font-bold text-gray-900">{batchCounter?.toString() || '0'}</dd>
          </div>
          <div>
            <dt className="text-sm text-gray-500">Active Contracts</dt>
            <dd className="text-lg font-bold text-gray-900">{activeCount?.toString() || '0'}</dd>
          </div>
        </dl>
      </div>

      {/* Controls */}
      <div className="mt-6 rounded-lg border border-gray-200 bg-white p-6">
        <h2 className="text-lg font-semibold text-gray-900">Controls</h2>

        <div className="mt-4 space-y-4">
          <div className="flex items-center justify-between">
            <div>
              <p className="font-medium text-gray-900">Toggle Automation</p>
              <p className="text-sm text-gray-500">Enable or disable automated weather monitoring.</p>
            </div>
            <button
              onClick={() => toggleAutomation({
                address: CONTRACTS.provider,
                abi: automatedInsuranceProviderAbi,
                functionName: 'setAutomationEnabled',
                args: [!automationEnabled],
              })}
              disabled={isToggling}
              className={`rounded-md px-4 py-2 text-sm font-semibold text-white shadow disabled:opacity-50 ${
                automationEnabled ? 'bg-red-600 hover:bg-red-500' : 'bg-green-600 hover:bg-green-500'
              }`}
            >
              {isToggling ? 'Updating...' : automationEnabled ? 'Disable' : 'Enable'}
            </button>
          </div>

          <hr />

          <div>
            <p className="font-medium text-gray-900">Set Upkeep Interval</p>
            <p className="text-sm text-gray-500 mb-2">Minimum 1 hour (3600 seconds).</p>
            <div className="flex gap-2">
              <input
                type="number"
                value={newInterval}
                onChange={(e) => setNewInterval(e.target.value)}
                placeholder="Seconds (e.g. 86400)"
                min="3600"
                className="flex-1 rounded-md border border-gray-300 px-3 py-2 text-sm shadow-sm focus:border-green-500 focus:ring-green-500"
              />
              <button
                onClick={() => {
                  if (!newInterval || Number(newInterval) < 3600) return
                  setInterval_({
                    address: CONTRACTS.provider,
                    abi: automatedInsuranceProviderAbi,
                    functionName: 'setUpkeepInterval',
                    args: [BigInt(newInterval)],
                  })
                }}
                disabled={isSettingInterval || !newInterval}
                className="rounded-md bg-gray-800 px-4 py-2 text-sm font-semibold text-white shadow hover:bg-gray-700 disabled:opacity-50"
              >
                {isSettingInterval ? 'Setting...' : 'Set'}
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}
