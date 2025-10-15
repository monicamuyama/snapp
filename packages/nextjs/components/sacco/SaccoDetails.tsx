"use client";

import { useMemo, useState } from "react";
import { Address, IntegerInput } from "~~/components/scaffold-stark";
import { useScaffoldReadContract, useScaffoldWriteContract } from "~~/hooks/scaffold-stark";

export const SaccoDetails = ({ groupId }: { groupId: string }) => {
  const id = useMemo(() => BigInt(groupId), [groupId]);
  const { data: info } = useScaffoldReadContract({
    contractName: "SaccoSimple",
    functionName: "get_sacco_info",
    args: [id],
  });
  const { data: balance } = useScaffoldReadContract({
    contractName: "SaccoSimple",
    functionName: "get_balance",
    args: [id],
  });

  const { sendAsync: joinAsync, isPending: joining } = useScaffoldWriteContract({
    contractName: "SaccoSimple",
    functionName: "join_sacco",
    args: [id],
  });

  const [contrib, setContrib] = useState<string | bigint>("");
  const { sendAsync: contributeAsync, isPending: contributing } = useScaffoldWriteContract({
    contractName: "SaccoSimple",
    functionName: "make_contribution",
    args: [id, contrib || 0n],
  });

  const name = (info as any)?.name as string | undefined;
  const creator = (info as any)?.creator as string | undefined;
  const contributionAmount = (info as any)?.contribution_amount as bigint | undefined;
  const memberCount = (info as any)?.member_count as bigint | undefined;

  return (
    <div className="px-4 py-6 max-w-2xl mx-auto space-y-6">
      <div className="card bg-base-100 border border-base-300">
        <div className="card-body gap-2">
          <h2 className="card-title">{name || `SACCO #${id}`}</h2>
          {creator && (
            <div className="text-sm">Creator: <Address address={creator} /></div>
          )}
          <div className="text-sm opacity-80">Required contribution (wei): {contributionAmount ? contributionAmount.toString() : "-"}</div>
          <div className="text-sm opacity-80">Members: {memberCount ? memberCount.toString() : "-"}</div>
          <div className="text-sm opacity-80">Balance (wei): {balance ? (balance as bigint).toString() : "0"}</div>
          <div className="card-actions mt-2 gap-2">
            <button className="btn btn-primary btn-sm" onClick={() => joinAsync()} disabled={joining}>Join</button>
          </div>
        </div>
      </div>

      <div className="card bg-base-100 border border-base-300">
        <div className="card-body gap-3">
          <h3 className="font-semibold">Contribute</h3>
          <IntegerInput value={contrib} onChange={setContrib} placeholder="Amount (wei)" />
          <div className="card-actions">
            <button className="btn btn-secondary" onClick={() => contributeAsync()} disabled={contributing}>
              {contributing ? <span className="loading loading-spinner loading-sm"></span> : "Contribute"}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};


