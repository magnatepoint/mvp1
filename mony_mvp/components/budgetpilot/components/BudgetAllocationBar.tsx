'use client'

interface BudgetAllocationBarProps {
  needsPct: number
  wantsPct: number
  savingsPct: number
}

export default function BudgetAllocationBar({
  needsPct,
  wantsPct,
  savingsPct,
}: BudgetAllocationBarProps) {
  const needsWidth = Math.max(0, Math.min(100, needsPct * 100))
  const wantsWidth = Math.max(0, Math.min(100, wantsPct * 100))
  const savingsWidth = Math.max(0, Math.min(100, savingsPct * 100))

  return (
    <div className="space-y-3">
      {/* Allocation Bar */}
      <div className="w-full h-6 rounded-lg overflow-hidden flex">
        {/* Needs */}
        <div
          className="bg-blue-500 transition-all"
          style={{ width: `${needsWidth}%` }}
        />
        {/* Wants */}
        <div
          className="bg-orange-500 transition-all"
          style={{ width: `${wantsWidth}%` }}
        />
        {/* Savings */}
        <div
          className="bg-green-500 transition-all"
          style={{ width: `${savingsWidth}%` }}
        />
      </div>

      {/* Labels */}
      <div className="flex items-center gap-4 flex-wrap">
        <div className="flex items-center gap-2">
          <div className="w-2 h-2 rounded-full bg-blue-500" />
          <span className="text-xs font-medium text-gray-300">
            Needs {Math.round(needsPct * 100)}%
          </span>
        </div>
        <div className="flex items-center gap-2">
          <div className="w-2 h-2 rounded-full bg-orange-500" />
          <span className="text-xs font-medium text-gray-300">
            Wants {Math.round(wantsPct * 100)}%
          </span>
        </div>
        <div className="flex items-center gap-2">
          <div className="w-2 h-2 rounded-full bg-green-500" />
          <span className="text-xs font-medium text-gray-300">
            Savings {Math.round(savingsPct * 100)}%
          </span>
        </div>
      </div>
    </div>
  )
}
