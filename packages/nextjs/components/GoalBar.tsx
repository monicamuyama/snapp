"use client";
import React from "react";

type GoalBarProps = {
  label?: string;
  value?: number; // current value
  target?: number; // goal target
  currency?: string;
  className?: string;
};

// replaced component implementation with improved robustness/accessibility
export function GoalBar({ label = "Goal", value = 40, target = 100, currency = "UGX", className = "" }: GoalBarProps) {
  const safeValue = Number.isFinite(value) ? value! : 0;
  const safeTarget = Number.isFinite(target) && target! > 0 ? target! : 1;
  const pct = Math.max(0, Math.min(100, Math.round((safeValue / safeTarget) * 100)));
  const formattedValue = safeValue.toLocaleString();
  const formattedTarget = safeTarget.toLocaleString();

  return (
    <div className={`w-full ${className}`}>
      <div className="flex items-baseline justify-between mb-2">
        <div className="text-sm font-medium">{label}</div>
        <div className="text-sm opacity-80">
          {formattedValue} / {formattedTarget} {currency}
        </div>
      </div>

      <div
        className="w-full bg-base-200 rounded-full h-3 overflow-hidden"
        role="progressbar"
        aria-valuemin={0}
        aria-valuemax={100}
        aria-valuenow={pct}
        aria-label={label}
      >
        <div className="bg-primary h-full rounded-full" style={{ width: `${pct}%` }} />
      </div>
    </div>
  );
}

// expose default as well so both `import GoalBar from ...` and `import { GoalBar } from ...` work
export default GoalBar;
