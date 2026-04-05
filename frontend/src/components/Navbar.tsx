'use client'

import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { ConnectKitButton } from 'connectkit'
import { useAccount, useChainId } from 'wagmi'
import { sepolia } from 'wagmi/chains'

const navLinks = [
  { href: '/farmer', label: 'Farmer' },
  { href: '/insurer', label: 'Insurer' },
  { href: '/attestations', label: 'Attestations' },
]

export function Navbar() {
  const pathname = usePathname()
  const { isConnected } = useAccount()
  const chainId = useChainId()
  const wrongNetwork = isConnected && chainId !== sepolia.id

  return (
    <nav className="border-b border-gray-200 bg-white">
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <div className="flex h-16 items-center justify-between">
          <div className="flex items-center gap-8">
            <Link href="/" className="text-xl font-bold text-green-700">
              CropShield
            </Link>
            <div className="flex gap-1">
              {navLinks.map((link) => {
                const isActive = pathname.startsWith(link.href)
                return (
                  <Link
                    key={link.href}
                    href={link.href}
                    className={`rounded-md px-3 py-2 text-sm font-medium transition-colors ${
                      isActive
                        ? 'bg-green-50 text-green-700'
                        : 'text-gray-600 hover:bg-gray-50 hover:text-gray-900'
                    }`}
                  >
                    {link.label}
                  </Link>
                )
              })}
            </div>
          </div>
          <div className="flex items-center gap-3">
            {wrongNetwork && (
              <span className="rounded-md bg-red-50 px-2 py-1 text-xs font-medium text-red-700">
                Wrong network — switch to Sepolia
              </span>
            )}
            <ConnectKitButton />
          </div>
        </div>
      </div>
    </nav>
  )
}
