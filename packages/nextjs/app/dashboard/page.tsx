"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { CustomConnectButton } from "~~/components/scaffold-stark/CustomConnectButton";
import { UsersIcon, PlusIcon, ArrowUpRightIcon } from "@heroicons/react/24/outline";
import * as GoalBarModule from "../../components/GoalBar";

const GoalBar = (GoalBarModule && (GoalBarModule.default ?? GoalBarModule.GoalBar ?? GoalBarModule)) as any;

const Dashboard = () => {
  const router = useRouter();

  return (
    <div className="min-h-screen bg-base-200">
      <header className="border-b bg-base-100">
        <div className="container mx-auto px-4 py-4 flex items-center justify-between">
          <h1 className="text-2xl font-bold text-primary">SACCO DeFi</h1>
          <div className="flex items-center gap-2">
            <CustomConnectButton />
          </div>
        </div>
      </header>

      <main className="container mx-auto px-4 py-8 space-y-8">
        {/* Wallet Balance Section */}
        <div className="rounded-2xl p-8 text-white shadow-md bg-gradient-to-br from-primary/70 via-secondary/60 to-accent/60">
          <h2 className="text-sm font-medium mb-2 opacity-90">Total Balance</h2>
          <p className="text-4xl font-bold mb-6">UGX 2,450,000</p>
          <div className="grid grid-cols-3 gap-4">
            <BalanceCard label="BTC" amount="0.0234" ugx="~UGX 1,200,000" />
            <BalanceCard label="USDC" amount="850.00" ugx="~UGX 850,000" />
            <BalanceCard label="STRK" amount="2,500" ugx="~UGX 400,000" />
          </div>
        </div>

        {/* Quick Actions */}
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          <button className="btn btn-outline h-24 flex flex-col gap-2" onClick={() => router.push("/sacco/new")}> 
            <PlusIcon className="h-6 w-6" />
            <span>Create SACCO</span>
          </button>
          <button className="btn btn-outline h-24 flex flex-col gap-2" onClick={() => router.push("/sacco")}> 
            <UsersIcon className="h-6 w-6" />
            <span>Join SACCO</span>
          </button>
          <button className="btn btn-outline h-24 flex flex-col gap-2" onClick={() => router.push("/goals")}> 
            <ArrowUpRightIcon className="h-6 w-6" />
            <span>Set Goal</span>
          </button>
          <button className="btn btn-outline h-24 flex flex-col gap-2" onClick={() => router.push("/wallet/send")}> 
            <ArrowUpRightIcon className="h-6 w-6" />
            <span>Send Money</span>
          </button>
        </div>

        {/* My SACCOs */}
        <div>
          <h2 className="text-xl font-semibold mb-4">My SACCOs</h2>
          <div className="grid md:grid-cols-2 gap-4">
            <SaccoCard
              title="Family Circle"
              icon={<UsersIcon className="h-5 w-5 opacity-60" />}
              members="8/10"
              contribution="UGX 50,000"
              next="3 days"
              ctaHref="/sacco/1"
            />
            <SaccoCard
              title="Business Group"
              icon={<ArrowUpRightIcon className="h-5 w-5 opacity-60" />}
              members="5/5"
              contribution="UGX 100,000"
              next="You (Next)"
              ctaHref="/sacco/2"
            />
          </div>
        </div>

        {/* Personal Goals */}
        <div>
          <h2 className="text-xl font-semibold mb-4">Personal Goals</h2>
          <div className="card bg-base-100 shadow-sm border">
            <div className="card-body pt-6">
              <GoalBar title="Emergency Fund" pct={60} current="UGX 600,000" goal="UGX 1,000,000" color="bg-success" />
              <GoalBar title="School Fees" pct={35} current="UGX 700,000" goal="UGX 2,000,000" color="bg-accent" />
            </div>
          </div>
        </div>
      </main>
    </div>
  );
};

const BalanceCard = ({ label, amount, ugx }: { label: string; amount: string; ugx: string }) => (
  <div>
    <p className="text-xs opacity-80 mb-1">{label}</p>
    <p className="font-semibold">{amount}</p>
    <p className="text-xs opacity-80">{ugx}</p>
  </div>
);

const SaccoCard = ({ title, icon, members, contribution, next, ctaHref }: { title: string; icon: React.ReactNode; members: string; contribution: string; next: string; ctaHref: string }) => (
  <div className="card bg-base-100 border hover:shadow-md transition-shadow">
    <div className="card-header px-6 pt-6">
      <div className="card-title flex items-center justify-between">
        <span>{title}</span>
        {icon}
      </div>
    </div>
    <div className="card-body pt-2">
      <div className="space-y-3 text-sm">
        <Row label="Members" value={members} />
        <Row label="Your Contribution" value={<span className="text-success font-medium">{contribution}</span>} />
        <Row label="Next Cycle" value={next} />
        <Link href={ctaHref} className="btn btn-primary btn-sm w-full mt-2">View Details</Link>
      </div>
    </div>
  </div>
);

const Row = ({ label, value }: { label: string; value: React.ReactNode }) => (
  <div className="flex justify-between">
    <span className="opacity-70">{label}</span>
    <span className="font-medium">{value}</span>
  </div>
);

export default Dashboard;


