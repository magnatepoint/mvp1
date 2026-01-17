'use client'

import type { CommittedBudget } from '@/types/budget'
import { glassCardPrimary } from '@/lib/theme/glass'
import BudgetAllocationBar from './BudgetAllocationBar'
import BudgetSummaryRow from './BudgetSummaryRow'

interface CommittedBudgetCardProps {
  committedBudget: CommittedBudget
}

export default function CommittedBudgetCard({ committedBudget }: CommittedBudgetCardProps) {
  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('en-IN', {
      style: 'currency',
      currency: 'INR',
      maximumFractionDigits: 0,
    }).format(amount)
  }

  const formatDate = (dateString: string) => {
    try {
      const date = new Date(dateString)
      return date.toLocaleDateString('en-IN', {
        year: 'numeric',
        month: 'long',
        day: 'numeric',
      })
    } catch {
      return dateString
    }
  }

  return (
    <div className={`${glassCardPrimary} p-5 space-y-5`}>
      {/* Header */}
      <div className="flex items-center justify-between">
        <h3 className="text-xl font-bold text-white">Your Committed Budget</h3>
        <span className="text-2xl font-bold text-green-400">✓</span>
      </div>

      {/* Budget Summary */}
      <div className="space-y-3">
        <BudgetSummaryRow
          label="Needs"
          percentage={committedBudget.alloc_needs_pct}
          color="blue"
        />
        <BudgetSummaryRow
          label="Wants"
          percentage={committedBudget.alloc_wants_pct}
          color="orange"
        />
        <BudgetSummaryRow
          label="Savings"
          percentage={committedBudget.alloc_assets_pct}
          color="green"
        />
      </div>

      {/* Allocation Bar */}
      <BudgetAllocationBar
        needsPct={committedBudget.alloc_needs_pct}
        wantsPct={committedBudget.alloc_wants_pct}
        savingsPct={committedBudget.alloc_assets_pct}
      />

      {/* Goal Allocations */}
      {committedBudget.goal_allocations && committedBudget.goal_allocations.length > 0 && (
        <div className="pt-4 border-t border-white/10 space-y-3">
          <h4 className="text-base font-semibold text-white">Goal Allocations</h4>
          <div className="space-y-2">
            {committedBudget.goal_allocations.map((allocation) => (
              <div key={allocation.ubcga_id} className="flex items-center justify-between">
                <span className="text-sm text-gray-300">
                  {allocation.goal_name || allocation.goal_id.substring(0, 8) + '...'}
                </span>
                <span className="text-sm font-medium text-white">
                  {formatCurrency(allocation.planned_amount)}
                </span>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Committed Date */}
      <div className="pt-2 border-t border-white/10">
        <p className="text-xs text-gray-400">
          Committed on {formatDate(committedBudget.committed_at)}
        </p>
      </div>
    </div>
  )
}
