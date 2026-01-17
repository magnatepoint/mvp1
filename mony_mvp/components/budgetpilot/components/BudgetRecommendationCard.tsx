'use client'

import type { BudgetRecommendation } from '@/types/budget'
import { glassCardPrimary } from '@/lib/theme/glass'
import BudgetAllocationBar from './BudgetAllocationBar'

interface BudgetRecommendationCardProps {
  recommendation: BudgetRecommendation
  isCommitted: boolean
  isCommitting: boolean
  onCommit: () => void
}

export default function BudgetRecommendationCard({
  recommendation,
  isCommitted,
  isCommitting,
  onCommit,
}: BudgetRecommendationCardProps) {
  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('en-IN', {
      style: 'currency',
      currency: 'INR',
      maximumFractionDigits: 0,
    }).format(amount)
  }

  return (
    <div className={`${glassCardPrimary} p-5 space-y-4`}>
      {/* Header */}
      <div className="flex items-start justify-between gap-4">
        <div className="flex-1 min-w-0">
          <h3 className="text-xl font-bold text-white mb-1">{recommendation.name}</h3>
          {recommendation.description && (
            <p className="text-sm text-gray-400 line-clamp-2">{recommendation.description}</p>
          )}
        </div>

        {/* Score Badge */}
        <div className="flex-shrink-0 px-3 py-2 rounded-lg bg-[#D4AF37]/20">
          <div className="text-center">
            <p className="text-xs font-medium text-gray-300 mb-1">Score</p>
            <p className="text-lg font-bold text-[#D4AF37]">
              {recommendation.score.toFixed(2)}
            </p>
          </div>
        </div>
      </div>

      {/* Allocation Bar */}
      <BudgetAllocationBar
        needsPct={recommendation.needs_budget_pct}
        wantsPct={recommendation.wants_budget_pct}
        savingsPct={recommendation.savings_budget_pct}
      />

      {/* Recommendation Reason */}
      <p className="text-sm text-gray-300 line-clamp-3">{recommendation.recommendation_reason}</p>

      {/* Goal Preview */}
      {recommendation.goal_preview && recommendation.goal_preview.length > 0 && (
        <div className="pt-3 border-t border-white/10 space-y-2">
          <h4 className="text-sm font-semibold text-white">Goal Allocation Preview</h4>
          <div className="space-y-2">
            {recommendation.goal_preview.slice(0, 3).map((goal) => (
              <div key={goal.goal_id} className="flex items-center justify-between">
                <span className="text-sm text-gray-300">{goal.goal_name}</span>
                <span className="text-sm font-medium text-white">
                  {formatCurrency(goal.allocation_amount)}
                </span>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Commit Button or Committed Badge */}
      {isCommitted ? (
        <div className="flex justify-end pt-2">
          <span className="px-4 py-2 rounded-lg bg-green-500/20 text-green-400 text-sm font-semibold">
            ✓ Committed
          </span>
        </div>
      ) : (
        <button
          onClick={onCommit}
          disabled={isCommitting}
          className={`w-full py-3 rounded-xl font-semibold transition-colors ${
            isCommitting
              ? 'bg-[#D4AF37]/50 text-black/50 cursor-not-allowed'
              : 'bg-[#D4AF37] text-black hover:bg-[#D4AF37]/90'
          }`}
        >
          {isCommitting ? (
            <span className="flex items-center justify-center gap-2">
              <div className="w-4 h-4 border-2 border-black/30 border-t-black rounded-full animate-spin" />
              Committing...
            </span>
          ) : (
            'Commit to This Plan'
          )}
        </button>
      )}
    </div>
  )
}
