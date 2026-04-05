import { defineConfig } from '@wagmi/cli'
import { react } from '@wagmi/cli/plugins'
import { automatedInsuranceProviderAbi } from './src/abi/AutomatedInsuranceProvider'
import { automatedInsuranceContractAbi } from './src/abi/AutomatedInsuranceContract'

export default defineConfig({
  out: 'src/generated.ts',
  contracts: [
    {
      name: 'AutomatedInsuranceProvider',
      abi: automatedInsuranceProviderAbi,
    },
    {
      name: 'AutomatedInsuranceContract',
      abi: automatedInsuranceContractAbi,
    },
  ],
  plugins: [react()],
})
