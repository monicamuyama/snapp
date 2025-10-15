"use client";

import { useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { InputBase, IntegerInput } from "~~/components/scaffold-stark";
import { useScaffoldWriteContract } from "~~/hooks/scaffold-stark";

export const CreateSacco = ({ compact = false }: { compact?: boolean }) => {
  const router = useRouter();
  const [name, setName] = useState("");
  const [maxMembers, setMaxMembers] = useState<string | bigint>("");
  const [contributionUgx, setContributionUgx] = useState<string>("");
  const [cycleDays, setCycleDays] = useState<string>("");

  // For MVP we still pass contribution as wei to the contract.
  const amountWei = useMemo(() => {
    // Placeholder: treat entered UGX as wei directly until FX/decimals mapping is added
    try {
      const n = BigInt(contributionUgx || "0");
      return n;
    } catch {
      return 0n;
    }
  }, [contributionUgx]);

  const { sendAsync, isPending } = useScaffoldWriteContract({
    contractName: "SaccoSimple" as any,
    functionName: "create_sacco" as any,
    args: [name, (maxMembers as any) || 0n, amountWei] as any,
  } as any);

  const totalPoolUgx = useMemo(() => {
    const a = Number(contributionUgx || 0);
    const m = Number(maxMembers || 0);
    if (Number.isNaN(a) || Number.isNaN(m)) return "0";
    return (a * m).toLocaleString();
  }, [contributionUgx, maxMembers]);

  const onCreate = async (e?: React.FormEvent) => {
    e?.preventDefault();
    try {
      await sendAsync();
      router.push("/sacco");
    } catch (e) {
      console.error("Create SACCO error", e);
    }
  };

  return (
    <div className={`card bg-base-100 border border-base-300 ${compact ? "card-compact" : ""}`}>
      <div className="card-body gap-4">
        <h2 className="card-title">Create SACCO Group</h2>

        <form className="grid gap-4" onSubmit={onCreate}>
          <div className="grid gap-2">
            <label className="text-sm font-medium">Group Name</label>
            <InputBase name="name" placeholder="e.g., Family Savings Circle" value={name} onChange={setName} />
          </div>

          <div className="grid gap-2">
            <label className="text-sm font-medium">Contribution Amount (UGX)</label>
            <input
              className="input input-bordered"
              inputMode="numeric"
              placeholder="50000"
              value={contributionUgx}
              onChange={e => setContributionUgx(e.target.value)}
              required
            />
            <p className="text-xs opacity-70">Amount each member contributes per cycle</p>
          </div>

          <div className="grid gap-2">
            <label className="text-sm font-medium">Cycle Length (Days)</label>
            <input
              className="input input-bordered"
              inputMode="numeric"
              placeholder="30"
              value={cycleDays}
              onChange={e => setCycleDays(e.target.value)}
              required
            />
            <p className="text-xs opacity-70">Used for UI reminders; not stored on-chain in MVP</p>
          </div>

          <div className="grid gap-2">
            <label className="text-sm font-medium">Maximum Members</label>
            <IntegerInput value={maxMembers} onChange={setMaxMembers} placeholder="10" />
          </div>

          <div className="rounded-lg border border-base-300 p-4 bg-base-200">
            <h3 className="font-semibold mb-2">Summary</h3>
            <div className="text-sm space-y-1">
              <p>
                Each member contributes <span className="font-semibold">UGX {contributionUgx || "0"}</span> every
                <span className="font-semibold"> {cycleDays || "0"} days</span>
              </p>
              <p>
                Total pool per cycle: <span className="font-semibold text-success">UGX {totalPoolUgx}</span>
              </p>
            </div>
          </div>

          <button type="submit" className="btn btn-primary w-full" disabled={isPending}>
            {isPending ? <span className="loading loading-spinner loading-sm"></span> : "Create SACCO"}
          </button>
        </form>
      </div>
    </div>
  );
};


