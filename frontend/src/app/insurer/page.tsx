'use client'

import Link from 'next/link'
import { useAccount, useReadContract } from 'wagmi'
import { ConnectKitButton } from 'connectkit'
import { useActiveContracts } from '@/hooks/useActiveContracts'
import { automatedInsuranceProviderAbi } from '@/abi/AutomatedInsuranceProvider'
import { CONTRACTS } from '@/config/contracts'
import { formatUSD, formatRainfall, formatAddress, formatTimestamp, getPolicyStatus, getStatusColor } from '@/lib/format'

export default function InsurerDashboard() {
  const { isConnected } = useAccount()
  const { contracts, activeCount, isLoading } = useActiveContracts()

  const { data: automationEnabled } = useReadContract({
    address: CONTRACTS.provider,
    abi: automatedInsuranceProviderAbi,
    functionName: 'automationEnabled',
  })

  const { data: lastUpkeep } = useReadContract({
    address: CONTRACTS.provider,
    abi: automatedInsuranceProviderAbi,
    functionName: 'lastUpkeepTimestamp',
  })

  if (!isConnected) {
    return (
      <div className="mx-auto max-w-4xl px-4 py-16 text-center">
        <h1 className="text-2xl font-bold text-gray-900">Insurer Dashboard</h1>
        <p className="mt-2 text-gray-600">Connect your wallet to manage insurance contracts.</p>
        <div className="mt-6 flex justify-center">
          <ConnectKitButton />
        </div>
      </div>
    )
  }

  return (
    <div className="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold text-gray-900">Insurer Dashboard</h1>
        <div className="flex gap-3">
          <Link
            href="/insurer/automation"
            className="rounded-md bg-white px-3 py-2 text-sm font-medium text-gray-700 ring-1 ring-gray-300 hover:bg-gray-50"
          >
            Automation
          </Link>
          <Link
            href="/insurer/create"
            className="rounded-md bg-green-600 px-3 py-2 text-sm font-semibold text-white shadow hover:bg-green-500"
          >
            + Create Policy
          </Link>
        </div>
      </div>

      {/* Stats Bar */}
      <div className="mt-6 grid grid-cols-3 gap-4">
        <div className="rounded-lg border border-gray-200 bg-white p-4">
          <p className="text-sm text-gray-500">Active Contracts</p>
          <p className="text-2xl font-bold text-gray-900">{activeCount}</p>
        </div>
        <div className="rounded-lg border border-gray-200 bg-white p-4">
          <p className="text-sm text-gray-500">Automation</p>
          <p className={`text-2xl font-bold ${automationEnabled ? 'text-green-600' : 'text-red-600'}`}>
            {automationEnabled ? 'Enabled' : 'Disabled'}
          </p>
        </div>
        <div className="rounded-lg border border-gray-200 bg-white p-4">
          <p className="text-sm text-gray-500">Last Upkeep</p>
          <p className="text-lg font-medium text-gray-900">
            {lastUpkeep ? formatTimestamp(lastUpkeep) : 'Never'}
          </p>
        </div>
      </div>

      {/* Contract Table */}
      {isLoading ? (
        <div className="mt-8 text-center text-gray-500">Loading contracts...</div>
      ) : contracts.length === 0 ? (
        <div className="mt-8 rounded-md border-2 border-dashed border-gray-300 p-12 text-center">
          <p className="text-gray-500">No active contracts.</p>
          <Link href="/insurer/create" className="mt-2 inline-block text-sm text-green-600 hover:text-green-500">
            Create your first policy
          </Link>
        </div>
      ) : (
        <div className="mt-6 overflow-hidden rounded-lg border border-gray-200 bg-white">
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-4 py-3 text-left text-xs font-medium uppercase text-gray-500">Contract</th>
                <th className="px-4 py-3 text-left text-xs font-medium uppercase text-gray-500">Client</th>
                <th className="px-4 py-3 text-left text-xs font-medium uppercase text-gray-500">Location</th>
                <th className="px-4 py-3 text-left text-xs font-medium uppercase text-gray-500">Status</th>
                <th className="px-4 py-3 text-left text-xs font-medium uppercase text-gray-500">Drought</th>
                <th className="px-4 py-3 text-left text-xs font-medium uppercase text-gray-500">Rainfall</th>
                <th className="px-4 py-3 text-left text-xs font-medium uppercase text-gray-500">Checks</th>
                <th className="px-4 py-3"></th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {contracts.map((c) => {
                const status = getPolicyStatus(c.contractActive, c.premiumPaid, c.contractPaid)
                const statusColor = getStatusColor(status)
                return (
                  <tr key={c.address} className="hover:bg-gray-50">
                    <td className="px-4 py-3 text-sm font-mono text-gray-900">{formatAddress(c.address)}</td>
                    <td className="px-4 py-3 text-sm text-gray-600">{formatAddress(c.client)}</td>
                    <td className="px-4 py-3 text-sm text-gray-900">{c.cropLocation}</td>
                    <td className="px-4 py-3">
                      <span className={`inline-flex rounded-full px-2 py-0.5 text-xs font-medium ${statusColor}`}>
                        {status.replace('_', ' ')}
                      </span>
                    </td>
                    <td className="px-4 py-3 text-sm text-gray-900">{c.daysWithoutRain.toString()}/3</td>
                    <td className="px-4 py-3 text-sm text-gray-900">{formatRainfall(c.currentRainfall)}</td>
                    <td className="px-4 py-3 text-sm text-gray-900">{c.requestCount.toString()}</td>
                    <td className="px-4 py-3 text-right">
                      <Link
                        href={`/insurer/contract/${c.address}`}
                        className="text-sm text-green-600 hover:text-green-500"
                      >
                        View
                      </Link>
                    </td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}
