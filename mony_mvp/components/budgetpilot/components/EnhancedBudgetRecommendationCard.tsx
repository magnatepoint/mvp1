'use client'

import { useState } from 'react'
import type { BudgetRecommendation } from '@/types/budget'
import { glassCardPrimary } from '@/lib/theme/glass'
import BudgetAllocationBar from './BudgetAllocationBar'

interface EnhancedBudgetRecommendationCardProps {
  recommendation: BudgetRecommendation
  isCommitted: boolean
  isCommitting: boolean
  onCommit: () => void
  onCompare?: () => void
}

export default function EnhancedBudgetRecommendationCard({
  recommendation,
  isCommitted,
  isCommitting,
  onCommit,
  onCompare,
}: EnhancedBudgetRecommendationCardProps) {
  const [expanded, setExpanded] = useState(false)

  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('en-IN', {
      style: 'currency',
      currency: 'INR',
      maximumFractionDigits: 0,
    }).format(amount)
  }

  return (
    <div className={`${glassCardPrimary} p-6 space-y-4 ${isCommitted ? 'ring-2 ring-green-500/50' : ''}`}>
      {/* Header */}
      <div className="flex items-start justify-between gap-4">
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-3 mb-2">
            <h3 className="text-xl font-bold text-white">{recommendation.name}</h3>
            {isCommitted && (
              <span className="px-2 py-1 rounded bg-green-500/20 text-green-400 text-xs font-semibold">
                ✓ Active
              </span>
            )}
          </div>
          {recommendation.description && (
            <p className="text-sm text-gray-400 line-clamp-2">{recommendation.description}</p>
          )}
        </div>

        {/* Score Badge */}
        <div className="flex-shrink-0 px-4 py-3 rounded-lg bg-[#D4AF37]/20 border border-[#D4AF37]/30">
          <div className="text-center">
            <p className="text-xs font-medium text-gray-300 mb-1">Score</p>
            <p className="text-2xl font-bold text-[#D4AF37]">{recommendation.score.toFixed(2)}</p>
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
      <div className="bg-white/5 p-3 rounded-lg">
        <p className="text-sm text-gray-300">{recommendation.recommendation_reason}</p>
      </div>

      {/* Expandable Goal Preview */}
      {recommendation.goal_preview && recommendation.goal_preview.length > 0 && (
        <div>
          <button
            onClick={() => setExpanded(!expanded)}
            className="flex items-center justify-between w-full text-left"
          >
            <h4 className="text-sm font-semibold text-white">
              Goal Allocation Preview ({recommendation.goal_preview.length} goals)
            </h4>
            <svg
              className={`w-5 h-5 transition-transform ${expanded ? 'rotate-180' : ''}`}
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
            </svg>
          </button>

          {expanded && (
            <div className="mt-3 space-y-2">
              {recommendation.goal_preview.map((goal) => (
                <div
                  key={goal.goal_id}
                  className="bg-white/5 p-3 rounded-lg flex items-center justify-between"
                >
                  <div>
                    <p className="text-sm font-medium text-white">{goal.goal_name}</p>
                    <p className="text-xs text-gray-400 mt-1">
                      {goal.allocation_pct.toFixed(1)}% of savings budget
                    </p>
                  </div>
                  <p className="text-sm font-bold text-[#D4AF37]">{formatCurrency(goal.allocation_amount)}</p>
                </div>
              ))}
            </div>
          )}
        </div>
      )}

      {/* Actions */}
      <div className="flex gap-3 pt-2">
        {onCompare && (
          <button
            onClick={onCompare}
            className="flex-1 px-4 py-2 bg-white/10 hover:bg-white/20 text-white rounded-lg font-medium transition-colors"
          >
            Compare
          </button>
        )}
        {isCommitted ? (
          <div className="flex-1 px-4 py-2 rounded-lg bg-green-500/20 text-green-400 text-center font-semibold">
            ✓ Committed
          </div>
        ) : (
          <button
            onClick={onCommit}
            disabled={isCommitting}
            className={`flex-1 py-2 rounded-lg font-semibold transition-colors ${
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
    </div>
  )
}
