"use client";

import Link from "next/link";
import { SaccoList } from "~~/components/sacco/SaccoList";
import { CreateSacco } from "~~/components/sacco/CreateSacco";

const SaccoHome = () => {
  return (
    <div className="px-4 py-6 max-w-3xl mx-auto space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold">SACCO</h1>
        <Link href="/sacco/new" className="btn btn-primary btn-sm">
          New SACCO
        </Link>
      </div>

      <CreateSacco compact />

      <div>
        <h2 className="text-lg font-semibold mb-2">Your SACCOs</h2>
        <SaccoList />
      </div>

      {/* Project Plan & MVP Roadmap */}
      <section className="bg-base-100 border rounded-2xl p-6 space-y-4">
        <h2 className="text-xl font-bold">MVP Plan — Lovable SACCO on Starknet</h2>
        <p className="text-sm opacity-80">
          High level implementation plan & immediate next tasks. See the design/problem context:
          <a className="ml-1 underline" href="https://hackmd.io/@espejelomar/B1FjnFxigg" target="_blank" rel="noreferrer">
            HackMD: Digital Onboarding for SACCOS
          </a>
        </p>

        <ol className="list-decimal list-inside space-y-2 text-sm">
          <li>
            Contracts (priority): core SACCO Cairo contracts — create groups, invite members, contributions, rotation & payouts.
            Deliverable: contracts/sacco.cairo + unit tests.
          </li>
          <li>
            Scaffold-Stark infra: deployment scripts, env config, local devnet, and account abstraction templates (paymaster stub).
            Deliverable: scripts/deploy.ts, scaffold-stark config.
          </li>
          <li>
            Wallet & Multi-currency UI: unified balances (BTC / USDC / UGX), conversion widget, mobile-first screens.
            Deliverable: components/wallet/*, pages/wallet.
          </li>
          <li>
            Cross-chain & Lightning hooks: integration points (Atomiq SDK) and BTC remittance demo flow (receive → swap to USDC).
            Deliverable: integrations/atomiq.ts (stubs) + example flow in UI.
          </li>
          <li>
            Personal Goals: lightweight on-chain stub + encrypted off-chain tracker for private goals (opt-in).
            Deliverable: components/GoalCard, service to encrypt & store goal metadata (IPFS or off-chain).
          </li>
          <li>
            KYC & Fiat rails: integrate KYC provider (Cleva-like) for tiered onboarding and fiat on/offramp APIs.
            Deliverable: integrations/kyc.ts (stubs) + onboarding flow guarded by KYC status.
          </li>
          <li>
            Account Abstraction & Paymaster: gasless flows using delegated USDC reserves for transaction fees (paymaster).
            Deliverable: paymaster contract stub + frontend gasless flow demo.
          </li>
          <li>
            Tests, Security & CI: unit/integration tests for contracts and e2e for frontend flows; add GitHub Actions pipelines.
            Deliverable: tests/, .github/workflows/ci.yml.
          </li>
        </ol>

        <div className="pt-2 border-t mt-2">
          <h3 className="font-semibold">Immediate next tasks (this week)</h3>
          <ul className="list-disc list-inside text-sm space-y-1">
            <li>Create contract skeletons: contracts/sacco.cairo, contracts/paymaster.cairo</li>
            <li>Add scaffold-stark deploy config and local devnet script</li>
            <li>Implement wallet component to show mocked balances and conversion widget</li>
            <li>Wire a KYC stub route and secure onboarding guard</li>
            <li>Document env vars and quick-start in README (root)</li>
          </ul>
        </div>

        <div className="flex gap-2 mt-3">
          <Link href="/debug" className="btn btn-outline btn-sm">
            Open Debug / Dev Tools
          </Link>
          <a href="https://hackmd.io/@espejelomar/B1FjnFxigg" target="_blank" rel="noreferrer" className="btn btn-ghost btn-sm">
            Read Problem Statement
          </a>
        </div>
      </section>
    </div>
  );
};

export default SaccoHome;


