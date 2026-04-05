export default function ContractDetail({ params }: { params: Promise<{ address: string }> }) {
  return (
    <div className="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
      <h1 className="text-2xl font-bold text-gray-900">Contract Detail</h1>
      <p className="mt-2 text-gray-600">Contract monitoring and actions will appear here.</p>
    </div>
  )
}
