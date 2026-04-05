'use client'

import { useAccount } from 'wagmi'
import { ConnectKitButton } from 'connectkit'

export default function InsurerDashboard() {
  const { isConnected } = useAccount()

  if (!isConnected) {
    return (
      <div className="mx-auto max-w-4xl px-4 py-16 text-center">
        <h1 className="text-2xl font-bold text-gray-900">Insurer Dashboard</h1>
        <p className="mt-2 text-gray-600">Connect your wallet to manage insurance contracts.</p>
        <div className="mt-6">
          <ConnectKitButton />
        </div>
      </div>
    )
  }

  return (
    <div className="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
      <h1 className="text-2xl font-bold text-gray-900">Insurer Dashboard</h1>
      <p className="mt-2 text-gray-600">Contract overview and automation status will appear here.</p>
    </div>
  )
}
