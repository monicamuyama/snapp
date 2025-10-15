# SACCO DeFi — MVP (Scaffold-Stark starter)

Overview
--------
This repository contains a starter MVP for a decentralized SACCO (savings group) built for Starknet using Scaffold-Stark / snfoundry patterns.  
Goal: a lovable, mobile-first MVP that supports group creation, member onboarding, contributions, rotation payouts, a personal goals module, multi-currency wallet UI, and integration points for KYC, fiat on/offramps, and a paymaster for gasless UX.

See the problem statement and design context:
https://hackmd.io/@espejelomar/B1FjnFxigg

Repository layout (high level)
------------------------------
- packages/snfoundry/contracts/src/ — Cairo contracts (sacco_core.cairo, paymaster.cairo, ...)
- packages/snfoundry/tests/ — contract test skeletons
- packages/snfoundry/scripts/ — helper scripts (deploy_devnet.sh)
- packages/nextjs/ — Next.js frontend (app/, components/, pages/)
- packages/nextjs/components/GoalBar.tsx — UI component used by Dashboard
- packages/nextjs/app/sacco/page.tsx — SACCO frontpage + project plan

Prerequisites
-------------
- Node.js 18+ (for frontend and scaffold-stark scripts)
- pnpm / npm / yarn
- Rust + cargo (if using snfoundry/snforge toolchain)
- starknet-devnet or scaffold-stark local devnet (or Docker image)
- scaffold-stark / snforge / starknet.py toolchain you prefer

Quick start (local dev)
-----------------------
1. Install dependencies
   - Frontend: cd packages/nextjs && pnpm install
   - Contracts: cd packages/snfoundry && (follow your Cairo toolchain install)

2. Start a local Starknet devnet
   - Example (starknet-devnet): starknet-devnet --port 5050 &
   - Or run your project's devnet docker container / scaffold-stark dev server.

3. Compile contracts
   - Replace with your toolchain command (snforge / scafold-stark)
   - Example placeholder:
     - cd packages/snfoundry
     - <compile contracts command>

4. Deploy contracts (local)
   - Use your preferred deploy tool (scaffold-stark, snforge, or starknet deploy)
   - Placeholder:
     - ./packages/snfoundry/scripts/deploy_devnet.sh
   - After deploy, record addresses in .env.local for frontend.

5. Run frontend (Next.js)
   - cd packages/nextjs
   - cp .env.example .env.local
   - pnpm dev
   - Open http://localhost:3000

Environment variables
---------------------
Create packages/nextjs/.env.local with the values below (examples):
- NEXT_PUBLIC_RPC_URL=http://127.0.0.1:5050
- NEXT_PUBLIC_SACCO_CORE_ADDRESS=<deployed_sacco_core_address>
- NEXT_PUBLIC_PAYMASTER_ADDRESS=<deployed_paymaster_address>
- NEXT_PUBLIC_USDC_ADDRESS=<usdc_token_address_on_devnet>
- NEXT_PUBLIC_ATOMIQ_API_KEY=...
- NEXT_PUBLIC_KYC_PROVIDER_URL=...

Contracts & tests
-----------------
- Primary contract: packages/snfoundry/contracts/src/sacco_core.cairo
  - Manages groups, members, contributions, rotation cycles, payouts, and emergency functions.
- Paymaster stub: packages/snfoundry/contracts/src/paymaster.cairo
  - Simple owner-managed deposit/withdraw & sponsor_tx() placeholder.
- Tests: packages/snfoundry/tests/ — test skeletons provided. Extend using your chosen test runner:
  - Options: snforge tests, pytest + starknet_py, or scaffold-stark test harness.

Suggested tests
- create_sacco_group flow (validation + events)
- join_sacco / leave_sacco / invite_member
- make_contribution, contribution balance updates, and transfer interactions
- start_rotation_cycle + process_payout (payout math, state updates)
- emergency_withdraw, pause/resume

Frontend
--------
- Mobile-first Next.js app in packages/nextjs
- Key pages/components:
  - /app/sacco/page.tsx — SACCO dashboard and project plan
  - components/sacco/* — CreateSacco, SaccoList, and other UI pieces
  - components/GoalBar.tsx — personal goal progress bar
- Wallet: implement mocked multi-currency wallet UI initially and replace with real RPC/Atomiq integrations later.

Integration points (stubs in repo)
----------------------------------
- Atomiq / Lightning integration: create integrations/atomiq.ts to wrap swap / lightning receive flows.
- KYC / Cleva-like provider: create integrations/kyc.ts; guard onboarding routes by KYC status.
- Fiat on/offramp: implement serverless endpoints or server adapters that call third-party APIs (offramp -> mobile money).

Security & privacy
------------------
- Treat personal goals as private data: store encrypted off-chain (IPFS or your backend) or use ZK approaches to protect sensitive metadata.
- Audit contracts and review arithmetic for Uint256 operations; add unit tests for edge conditions.
- Add RBAC checks and restrict admin-only functions.

CI / CD
-------
- Add GitHub Actions for:
  - Contract lint & compile
  - Unit tests (contracts + frontend)
  - Build & deploy to testnet (on tagged commits)
- Placeholders: .github/workflows/ci.yml — add matrix for Node & Rust toolchains.

Roadmap & next steps (prioritized)
----------------------------------
1. Contracts: finalize sacco_core + paymaster, add safe u256 helpers and tests.
2. Dev infra: compile & deploy scripts (scaffold-stark/snforge).
3. Wallet UI: mocked multi-currency balances + conversion widget.
4. Atomiq & Lightning: integration stubs + demo flow (BTC -> USDC).
5. KYC & fiat rails: stub provider + onboarding guard.
6. Account abstraction: implement paymaster integration and gasless onboarding demo.
7. Audit & CI: tests, security checks, and GitHub Actions.

Contributing
------------
- Follow standard Git workflow. Open issues for features/bugs.
- Add unit tests for contracts and components. Keep PRs small and focused.
- Document any third-party integrations and required keys in .env.example.

Useful links & references
-------------------------
- HackMD problem statement: https://hackmd.io/@espejelomar/B1FjnFxigg
- Scaffold-Stark: https://github.com/shardlabs/scaffold-starknet (replace with your preferred tool)
- Starknet Devnet / snforge: check your toolchain docs

Contact / help
--------------
If you want, I can:
- scaffold a complete deploy script using scaffold-stark (provide exact CLI),
- generate runnable pytest/snforge tests,
- add CI workflow (.github/workflows/ci.yml),
- or scaffold frontend pages for onboarding, wallet, KYC, and goals.
