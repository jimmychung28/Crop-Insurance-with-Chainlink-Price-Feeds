'use client'

import { use } from 'react'
import Link from 'next/link'
import { useReadContract } from 'wagmi'
import { easAbi } from '@/abi/EAS'
import { easInsuranceManagerAbi } from '@/abi/EASInsuranceManager'
import { CONTRACTS } from '@/config/contracts'
import { formatAddress, formatTimestamp } from '@/lib/format'
import { ATTESTATION_TYPES, decodeAttestationData, CLAIM_STATUS_LABELS, type AttestationType } from '@/lib/attestations'

export default function AttestationDetail({ params }: { params: Promise<{ uid: string }> }) {
  const { uid } = use(params)
  const uidBytes = uid as `0x${string}`

  const { data: attestation, isLoading } = useReadContract({
    address: CONTRACTS.eas,
    abi: easAbi,
    functionName: 'getAttestation',
    args: [uidBytes],
  })

  const { data: isValid } = useReadContract({
    address: CONTRACTS.easManager,
    abi: easInsuranceManagerAbi,
    functionName: 'isValidAttestation',
    args: [uidBytes],
    query: { enabled: CONTRACTS.easManager !== '0x0000000000000000000000000000000000000000' },
  })

  if (isLoading) {
    return <div className="mx-auto max-w-4xl px-4 py-8 text-center text-gray-500">Loading attestation...</div>
  }

  if (!attestation) {
    return (
      <div className="mx-auto max-w-4xl px-4 py-8">
        <div className="rounded-md bg-red-50 p-4 text-sm text-red-700">Attestation not found.</div>
      </div>
    )
  }

  const att = attestation as {
    uid: `0x${string}`; schema: `0x${string}`; time: bigint; expirationTime: bigint;
    revocationTime: bigint; refUID: `0x${string}`; recipient: `0x${string}`;
    attester: `0x${string}`; revocable: boolean; data: `0x${string}`;
  }

  const isRevoked = att.revocationTime > 0n
  const isExpired = att.expirationTime > 0n && att.expirationTime < BigInt(Math.floor(Date.now() / 1000))
  const hasRef = att.refUID !== '0x0000000000000000000000000000000000000000000000000000000000000000'

  // Try to decode data for each known schema type
  let decodedData: Record<string, unknown> | null = null
  let matchedType: AttestationType | null = null

  for (const type of ATTESTATION_TYPES) {
    try {
      const decoded = decodeAttestationData(type, att.data)
      if (decoded) {
        decodedData = decoded as unknown as Record<string, unknown>
        matchedType = type
        break
      }
    } catch {
      // Try next type
    }
  }

  return (
    <div className="mx-auto max-w-4xl px-4 py-8 sm:px-6 lg:px-8">
      <div className="mb-6">
        <Link href="/attestations" className="text-sm text-green-600 hover:text-green-500">&larr; Back to Explorer</Link>
      </div>

      <div className="flex items-start justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Attestation</h1>
          <p className="mt-1 text-xs text-gray-500 font-mono break-all">{uid}</p>
        </div>
        <div className="flex gap-2">
          {isValid && (
            <span className="inline-flex items-center rounded-full bg-green-100 px-3 py-1 text-xs font-medium text-green-800">
              Verified
            </span>
          )}
          {isRevoked && (
            <span className="inline-flex items-center rounded-full bg-red-100 px-3 py-1 text-xs font-medium text-red-800">
              Revoked
            </span>
          )}
          {isExpired && (
            <span className="inline-flex items-center rounded-full bg-yellow-100 px-3 py-1 text-xs font-medium text-yellow-800">
              Expired
            </span>
          )}
          {matchedType && (
            <span className="inline-flex items-center rounded-full bg-blue-100 px-3 py-1 text-xs font-medium text-blue-800">
              {matchedType}
            </span>
          )}
        </div>
      </div>

      {/* Envelope */}
      <div className="mt-6 rounded-lg border border-gray-200 bg-white p-6">
        <h2 className="text-lg font-semibold text-gray-900">Attestation Envelope</h2>
        <dl className="mt-4 grid grid-cols-2 gap-4">
          <div>
            <dt className="text-sm text-gray-500">Schema</dt>
            <dd className="text-sm font-mono text-gray-900">{formatAddress(att.schema)}</dd>
          </div>
          <div>
            <dt className="text-sm text-gray-500">Created</dt>
            <dd className="font-medium text-gray-900">{formatTimestamp(att.time)}</dd>
          </div>
          <div>
            <dt className="text-sm text-gray-500">Attester</dt>
            <dd className="text-sm font-mono text-gray-900">{formatAddress(att.attester)}</dd>
          </div>
          <div>
            <dt className="text-sm text-gray-500">Recipient</dt>
            <dd className="text-sm font-mono text-gray-900">{formatAddress(att.recipient)}</dd>
          </div>
          <div>
            <dt className="text-sm text-gray-500">Expiration</dt>
            <dd className="font-medium text-gray-900">
              {att.expirationTime > 0n ? formatTimestamp(att.expirationTime) : 'None'}
            </dd>
          </div>
          <div>
            <dt className="text-sm text-gray-500">Revocable</dt>
            <dd className="font-medium text-gray-900">{att.revocable ? 'Yes' : 'No (immutable)'}</dd>
          </div>
          {hasRef && (
            <div className="col-span-2">
              <dt className="text-sm text-gray-500">References</dt>
              <dd>
                <Link href={`/attestations/${att.refUID}`} className="text-sm font-mono text-green-600 hover:text-green-500">
                  {formatAddress(att.refUID)}
                </Link>
              </dd>
            </div>
          )}
        </dl>
      </div>

      {/* Decoded Data */}
      {decodedData && (
        <div className="mt-6 rounded-lg border border-gray-200 bg-white p-6">
          <h2 className="text-lg font-semibold text-gray-900">Decoded Data ({matchedType})</h2>
          <dl className="mt-4 space-y-3">
            {Object.entries(decodedData).map(([key, value]) => (
              <div key={key} className="flex justify-between border-b border-gray-100 pb-2">
                <dt className="text-sm text-gray-500">{key}</dt>
                <dd className="text-sm font-medium text-gray-900 text-right max-w-[60%] break-all">
                  {key === 'claimStatus' ? CLAIM_STATUS_LABELS[Number(value)] || String(value) : String(value)}
                </dd>
              </div>
            ))}
          </dl>
        </div>
      )}

      {/* Raw Data */}
      <div className="mt-6 rounded-lg border border-gray-200 bg-white p-6">
        <h2 className="text-lg font-semibold text-gray-900">Raw Data</h2>
        <pre className="mt-4 overflow-x-auto rounded-md bg-gray-50 p-4 text-xs text-gray-700">
          {att.data}
        </pre>
      </div>

      <div className="mt-4 text-right">
        <a
          href={`https://sepolia.easscan.org/attestation/view/${uid}`}
          target="_blank"
          rel="noopener noreferrer"
          className="text-sm text-green-600 hover:text-green-500"
        >
          View on EASScan &rarr;
        </a>
      </div>
    </div>
  )
}
