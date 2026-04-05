'use client'

import { useState } from 'react'
import Link from 'next/link'
import { useAccount, useReadContract } from 'wagmi'
import { type Address } from 'viem'
import { easInsuranceManagerAbi } from '@/abi/EASInsuranceManager'
import { CONTRACTS } from '@/config/contracts'
import { formatAddress } from '@/lib/format'

type Tab = 'client' | 'policy' | 'weather'

export default function AttestationBrowser() {
  const { address } = useAccount()
  const [tab, setTab] = useState<Tab>('client')
  const [searchInput, setSearchInput] = useState('')

  const isConfigured = CONTRACTS.easManager !== '0x0000000000000000000000000000000000000000'

  const { data: stats } = useReadContract({
    address: CONTRACTS.easManager,
    abi: easInsuranceManagerAbi,
    functionName: 'getAttestationStats',
    query: { enabled: isConfigured },
  })

  const { data: clientAttestations } = useReadContract({
    address: CONTRACTS.easManager,
    abi: easInsuranceManagerAbi,
    functionName: 'getClientAttestations',
    args: address ? [address] : undefined,
    query: { enabled: isConfigured && !!address && tab === 'client' },
  })

  const { data: policyAttestations } = useReadContract({
    address: CONTRACTS.easManager,
    abi: easInsuranceManagerAbi,
    functionName: 'getPolicyAttestations',
    args: searchInput ? [searchInput as Address] : undefined,
    query: { enabled: isConfigured && !!searchInput && tab === 'policy' },
  })

  const { data: weatherAttestations } = useReadContract({
    address: CONTRACTS.easManager,
    abi: easInsuranceManagerAbi,
    functionName: 'getWeatherAttestations',
    args: searchInput ? [searchInput] : undefined,
    query: { enabled: isConfigured && !!searchInput && tab === 'weather' },
  })

  const currentAttestations = tab === 'client'
    ? (clientAttestations as `0x${string}`[]) || []
    : tab === 'policy'
    ? (policyAttestations as `0x${string}`[]) || []
    : (weatherAttestations as `0x${string}`[]) || []

  const statEntries = stats ? [
    { label: 'Policies', value: Number(stats[0]) },
    { label: 'Weather', value: Number(stats[1]) },
    { label: 'Claims', value: Number(stats[2]) },
    { label: 'Compliance', value: Number(stats[3]) },
    { label: 'Premiums', value: Number(stats[4]) },
  ] : []

  return (
    <div className="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
      <h1 className="text-2xl font-bold text-gray-900">Attestation Explorer</h1>
      <p className="mt-1 text-sm text-gray-600">Browse and verify EAS attestations for insurance records.</p>

      {!isConfigured && (
        <div className="mt-6 rounded-md bg-yellow-50 p-4 text-sm text-yellow-700">
          EAS Manager not configured. Set NEXT_PUBLIC_EAS_MANAGER_ADDRESS in your environment.
        </div>
      )}

      {/* Stats */}
      {statEntries.length > 0 && (
        <div className="mt-6 grid grid-cols-5 gap-4">
          {statEntries.map((s) => (
            <div key={s.label} className="rounded-lg border border-gray-200 bg-white p-4 text-center">
              <p className="text-2xl font-bold text-gray-900">{s.value}</p>
              <p className="text-sm text-gray-500">{s.label}</p>
            </div>
          ))}
        </div>
      )}

      {/* Tabs */}
      <div className="mt-6 flex gap-1 border-b border-gray-200">
        {([
          { id: 'client' as const, label: 'My Attestations' },
          { id: 'policy' as const, label: 'By Policy' },
          { id: 'weather' as const, label: 'By Location' },
        ]).map((t) => (
          <button
            key={t.id}
            onClick={() => setTab(t.id)}
            className={`px-4 py-2 text-sm font-medium border-b-2 transition-colors ${
              tab === t.id ? 'border-green-600 text-green-600' : 'border-transparent text-gray-500 hover:text-gray-700'
            }`}
          >
            {t.label}
          </button>
        ))}
      </div>

      {/* Search */}
      {tab !== 'client' && (
        <div className="mt-4">
          <input
            type="text"
            value={searchInput}
            onChange={(e) => setSearchInput(e.target.value)}
            placeholder={tab === 'policy' ? 'Contract address (0x...)' : 'Location (e.g. London,UK)'}
            className="block w-full rounded-md border border-gray-300 px-3 py-2 text-sm shadow-sm focus:border-green-500 focus:ring-green-500"
          />
        </div>
      )}

      {/* Results */}
      <div className="mt-4">
        {currentAttestations.length === 0 ? (
          <div className="rounded-md border-2 border-dashed border-gray-300 p-8 text-center text-gray-500">
            {tab === 'client' ? 'No attestations found for your wallet.' : 'Enter a search query above.'}
          </div>
        ) : (
          <div className="overflow-hidden rounded-lg border border-gray-200 bg-white">
            <table className="min-w-full divide-y divide-gray-200">
              <thead className="bg-gray-50">
                <tr>
                  <th className="px-4 py-3 text-left text-xs font-medium uppercase text-gray-500">UID</th>
                  <th className="px-4 py-3"></th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-200">
                {currentAttestations.map((uid) => (
                  <tr key={uid} className="hover:bg-gray-50">
                    <td className="px-4 py-3 text-sm font-mono text-gray-900">{formatAddress(uid)}</td>
                    <td className="px-4 py-3 text-right">
                      <Link href={`/attestations/${uid}`} className="text-sm text-green-600 hover:text-green-500">
                        View
                      </Link>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  )
}
