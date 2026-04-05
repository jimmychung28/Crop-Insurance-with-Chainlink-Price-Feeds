'use client'

import { useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi'
import { type Address, erc20Abi } from 'viem'
import { automatedInsuranceProviderAbi } from '@/abi/AutomatedInsuranceProvider'
import { automatedInsuranceContractAbi } from '@/abi/AutomatedInsuranceContract'
import { CONTRACTS } from '@/config/contracts'

export function usePremiumPayment(contractAddress: Address) {
  const { data: premiumInfo } = useReadContract({
    address: CONTRACTS.provider,
    abi: automatedInsuranceProviderAbi,
    functionName: 'premiumInfo',
    args: [contractAddress],
  })

  const { data: paymentToken } = useReadContract({
    address: contractAddress,
    abi: automatedInsuranceContractAbi,
    functionName: 'paymentToken',
  })

  const { data: ethPrice } = useReadContract({
    address: CONTRACTS.provider,
    abi: automatedInsuranceProviderAbi,
    functionName: 'getLatestPrice',
  })

  const isEthPayment = paymentToken === '0x0000000000000000000000000000000000000000'

  const { data: tokenAmount } = useReadContract({
    address: CONTRACTS.provider,
    abi: automatedInsuranceProviderAbi,
    functionName: 'getTokenAmountForUSD',
    args: paymentToken && !isEthPayment ? [paymentToken as Address, premiumInfo?.[0] || 0n] : undefined,
    query: { enabled: !!paymentToken && !isEthPayment && !!premiumInfo },
  })

  const { data: allowance } = useReadContract({
    address: paymentToken as Address,
    abi: erc20Abi,
    functionName: 'allowance',
    args: [contractAddress, CONTRACTS.provider],
    query: { enabled: !!paymentToken && !isEthPayment },
  })

  // Calculate ETH amount with 3% buffer
  const ethAmount = (ethPrice && premiumInfo?.[0])
    ? (premiumInfo[0] * BigInt(1e18) * 103n) / (BigInt(ethPrice.toString()) * 100n)
    : 0n

  const needsApproval = !isEthPayment && tokenAmount && allowance !== undefined && allowance < tokenAmount

  // Approve ERC20
  const { writeContract: approve, data: approveTxHash, isPending: isApproving } = useWriteContract()
  const { isLoading: isApproveConfirming, isSuccess: isApproveConfirmed } = useWaitForTransactionReceipt({ hash: approveTxHash })

  // Pay premium
  const { writeContract: pay, data: payTxHash, isPending: isPaying } = useWriteContract()
  const { isLoading: isPayConfirming, isSuccess: isPayConfirmed } = useWaitForTransactionReceipt({ hash: payTxHash })

  function handleApprove() {
    if (!paymentToken || !tokenAmount) return
    approve({
      address: paymentToken as Address,
      abi: erc20Abi,
      functionName: 'approve',
      args: [CONTRACTS.provider, tokenAmount],
    })
  }

  function handlePay() {
    pay({
      address: CONTRACTS.provider,
      abi: automatedInsuranceProviderAbi,
      functionName: 'payPremium',
      args: [contractAddress],
      value: isEthPayment ? ethAmount : 0n,
    })
  }

  return {
    premiumInfo,
    paymentToken: paymentToken as Address | undefined,
    isEthPayment,
    ethAmount,
    tokenAmount,
    ethPrice,
    needsApproval,
    handleApprove,
    handlePay,
    isApproving: isApproving || isApproveConfirming,
    isApproveConfirmed,
    isPaying: isPaying || isPayConfirming,
    isPayConfirmed,
    approveTxHash,
    payTxHash,
  }
}
