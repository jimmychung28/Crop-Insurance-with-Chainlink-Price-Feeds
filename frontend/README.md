# CropShield Frontend

Two-sided dApp frontend for the crop insurance system.

## Setup

```bash
cd frontend
npm install
cp .env.local.example .env.local  # Edit with your addresses
npm run dev
```

## Environment Variables

| Variable | Description |
|----------|-------------|
| `NEXT_PUBLIC_SEPOLIA_RPC_URL` | Sepolia RPC endpoint |
| `NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID` | WalletConnect project ID (optional) |
| `NEXT_PUBLIC_PROVIDER_ADDRESS` | Deployed AutomatedInsuranceProvider address |
| `NEXT_PUBLIC_EAS_MANAGER_ADDRESS` | Deployed EASInsuranceManager address |
| `NEXT_PUBLIC_USDC_ADDRESS` | USDC token on Sepolia |
| `NEXT_PUBLIC_DAI_ADDRESS` | DAI token on Sepolia |

## Routes

| Route | Role | Description |
|-------|------|-------------|
| `/farmer` | Farmer | Policy list with status, rainfall, drought indicator |
| `/farmer/policy/[address]` | Farmer | Policy detail with weather panel and timeline |
| `/farmer/pay/[address]` | Farmer | Premium payment (ETH or ERC20 with approval flow) |
| `/insurer` | Insurer | Active contracts table with automation status |
| `/insurer/create` | Insurer | Create new insurance policy form |
| `/insurer/contract/[address]` | Insurer | Contract detail with claim/update actions |
| `/insurer/automation` | Insurer | Chainlink Automation toggle and interval config |
| `/attestations` | Both | EAS attestation browser with stats and search |
| `/attestations/[uid]` | Both | Attestation detail with decoded data and verification |

## ABI Management

ABIs are manually defined in `src/abi/`. To regenerate typed hooks after ABI changes:

```bash
npx wagmi generate
```

## Tech Stack

- Next.js 15+ (App Router)
- wagmi v2 + viem
- ConnectKit (wallet connection)
- Tailwind CSS
- TypeScript
