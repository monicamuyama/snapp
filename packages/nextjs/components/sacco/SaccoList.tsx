"use client";

import Link from "next/link";
import { useMemo } from "react";
import { useScaffoldReadContract } from "~~/hooks/scaffold-stark";

export const SaccoList = () => {
  const { data: total } = useScaffoldReadContract({
    contractName: "SaccoSimple",
    functionName: "get_total_saccos",
  });

  const ids = useMemo(() => {
    const n = Number(total || 0n);
    return Array.from({ length: n }, (_, i) => BigInt(i + 1));
  }, [total]);

  return (
    <div className="grid gap-3">
      {ids.length === 0 ? (
        <div className="text-sm opacity-70">No SACCOs yet</div>
      ) : (
        ids.map(id => <SaccoRow key={id.toString()} id={id} />)
      )}
    </div>
  );
};

const SaccoRow = ({ id }: { id: bigint }) => {
  const { data: info } = useScaffoldReadContract({
    contractName: "SaccoSimple",
    functionName: "get_sacco_info",
    args: [id],
  });

  const name = (info as any)?.name as string | undefined;
  const memberCount = (info as any)?.member_count as bigint | undefined;

  return (
    <Link href={`/sacco/${id}`} className="flex items-center justify-between p-3 rounded-xl bg-base-100 border border-base-300">
      <div className="font-medium">{name || `SACCO #${id}`}</div>
      <div className="text-sm opacity-70">Members: {memberCount ? memberCount.toString() : "-"}</div>
    </Link>
  );
};


