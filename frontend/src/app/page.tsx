import Link from 'next/link'

export default function Home() {
  return (
    <div className="mx-auto max-w-4xl px-4 py-16 text-center">
      <h1 className="text-4xl font-bold tracking-tight text-gray-900 sm:text-5xl">
        CropShield
      </h1>
      <p className="mt-4 text-lg text-gray-600">
        Decentralized parametric crop insurance powered by Chainlink oracles and Ethereum Attestation Service.
      </p>
      <div className="mt-10 flex justify-center gap-4">
        <Link
          href="/farmer"
          className="rounded-lg bg-green-600 px-6 py-3 text-sm font-semibold text-white shadow hover:bg-green-500 transition-colors"
        >
          Farmer Dashboard
        </Link>
        <Link
          href="/insurer"
          className="rounded-lg bg-white px-6 py-3 text-sm font-semibold text-gray-900 shadow ring-1 ring-gray-200 hover:bg-gray-50 transition-colors"
        >
          Insurer Dashboard
        </Link>
      </div>
    </div>
  )
}
