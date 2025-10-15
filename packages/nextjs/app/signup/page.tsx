"use client";

import Link from "next/link";
import { SaccoList } from "~~/components/sacco/SaccoList";
import { CreateSacco } from "~~/components/sacco/CreateSacco";

const Signup = () => {
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

        <div className="flex gap-2 mt-3">
          <Link href="/debug" className="btn btn-outline btn-sm">
            Open Debug / Dev Tools
          </Link>
          <a href="https://hackmd.io/@espejelomar/B1FjnFxigg" target="_blank" rel="noreferrer" className="btn btn-ghost btn-sm">
            Read Problem Statement
          </a>
        </div>
    </div>
  );
};

export default Signup;


