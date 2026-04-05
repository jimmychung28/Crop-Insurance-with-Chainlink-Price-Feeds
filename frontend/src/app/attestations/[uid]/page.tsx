export default function AttestationDetail({ params }: { params: Promise<{ uid: string }> }) {
  return (
    <div className="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
      <h1 className="text-2xl font-bold text-gray-900">Attestation Detail</h1>
      <p className="mt-2 text-gray-600">Attestation data and verification will appear here.</p>
    </div>
  )
}
