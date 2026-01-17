'use client'

import type { BudgetRecommendation, CommittedBudget } from '@/types/budget'
import { glassCardPrimary } from '@/lib/theme/glass'
import BudgetAllocationBar from './BudgetAllocationBar'

interface BudgetComparisonModalProps {
  committedBudget: CommittedBudget | null
  recommendation: BudgetRecommendation
  isOpen: boolean
  onClose: () => void
}

export default function BudgetComparisonModal({
  committedBudget,
  recommendation,
  isOpen,
  onClose,
}: BudgetComparisonModalProps) {
  if (!isOpen) return null

  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('en-IN', {
      style: 'currency',
      currency: 'INR',
      maximumFractionDigits: 0,
    }).format(amount)
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm">
      <div className={`${glassCardPrimary} p-6 max-w-3xl w-full mx-4 max-h-[90vh] overflow-y-auto`}>
        <div className="flex items-center justify-between mb-6">
          <h2 className="text-2xl font-bold">Compare Budget Plans</h2>
          <button
            onClick={onClose}
            className="p-2 rounded-lg hover:bg-white/10 transition-colors"
          >
            <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          {/* Committed Budget */}
          <div>
            <h3 className="text-lg font-semibold mb-4 text-gray-300">
              {committedBudget ? 'Your Current Budget' : 'No Budget Committed'}
            </h3>
            {committedBudget ? (
              <div className="space-y-4">
                <BudgetAllocationBar
                  needsPct={committedBudget.alloc_needs_pct}
                  wantsPct={committedBudget.alloc_wants_pct}
                  savingsPct={committedBudget.alloc_assets_pct}
                />
                <div className="space-y-2 text-sm">
                  <div className="flex justify-between">
                    <span className="text-gray-400">Needs:</span>
                    <span className="text-blue-400 font-semibold">
                      {(committedBudget.alloc_needs_pct * 100).toFixed(0)}%
                    </span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-gray-400">Wants:</span>
                    <span className="text-orange-400 font-semibold">
                      {(committedBudget.alloc_wants_pct * 100).toFixed(0)}%
                    </span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-gray-400">Savings:</span>
                    <span className="text-green-400 font-semibold">
                      {(committedBudget.alloc_assets_pct * 100).toFixed(0)}%
                    </span>
                  </div>
                </div>
              </div>
            ) : (
              <p className="text-gray-400 text-sm">No budget committed yet</p>
            )}
          </div>

          {/* Recommended Budget */}
          <div>
            <h3 className="text-lg font-semibold mb-4 text-[#D4AF37]">{recommendation.name}</h3>
            <div className="space-y-4">
              <BudgetAllocationBar
                needsPct={recommendation.needs_budget_pct}
                wantsPct={recommendation.wants_budget_pct}
                savingsPct={recommendation.savings_budget_pct}
              />
              <div className="space-y-2 text-sm">
                <div className="flex justify-between">
                  <span className="text-gray-400">Needs:</span>
                  <span className="text-blue-400 font-semibold">
                    {(recommendation.needs_budget_pct * 100).toFixed(0)}%
                  </span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-400">Wants:</span>
                  <span className="text-orange-400 font-semibold">
                    {(recommendation.wants_budget_pct * 100).toFixed(0)}%
                  </span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-400">Savings:</span>
                  <span className="text-green-400 font-semibold">
                    {(recommendation.savings_budget_pct * 100).toFixed(0)}%
                  </span>
                </div>
              </div>
              <div className="bg-white/5 p-3 rounded-lg">
                <p className="text-xs text-gray-400 mb-1">Recommendation Score</p>
                <p className="text-2xl font-bold text-[#D4AF37]">{recommendation.score.toFixed(2)}</p>
              </div>
              <div className="bg-white/5 p-3 rounded-lg">
                <p className="text-xs text-gray-400 mb-1">Why this plan?</p>
                <p className="text-sm text-gray-300">{recommendation.recommendation_reason}</p>
              </div>
            </div>
          </div>
        </div>

        {/* Differences */}
        {committedBudget && (
          <div className="mt-6 pt-6 border-t border-white/10">
            <h4 className="text-base font-semibold mb-3">Key Differences</h4>
            <div className="space-y-2 text-sm">
              <div className="flex justify-between">
                <span className="text-gray-400">Needs change:</span>
                <span
                  className={`font-semibold ${
                    recommendation.needs_budget_pct > committedBudget.alloc_needs_pct
                      ? 'text-red-400'
                      : 'text-green-400'
                  }`}
                >
                  {recommendation.needs_budget_pct > committedBudget.alloc_needs_pct ? '+' : ''}
                  {((recommendation.needs_budget_pct - committedBudget.alloc_needs_pct) * 100).toFixed(1)}%
                </span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-400">Wants change:</span>
                <span
                  className={`font-semibold ${
                    recommendation.wants_budget_pct > committedBudget.alloc_wants_pct
                      ? 'text-red-400'
                      : 'text-green-400'
                  }`}
                >
                  {recommendation.wants_budget_pct > committedBudget.alloc_wants_pct ? '+' : ''}
                  {((recommendation.wants_budget_pct - committedBudget.alloc_wants_pct) * 100).toFixed(1)}%
                </span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-400">Savings change:</span>
                <span
                  className={`font-semibold ${
                    recommendation.savings_budget_pct > committedBudget.alloc_assets_pct
                      ? 'text-green-400'
                      : 'text-red-400'
                  }`}
                >
                  {recommendation.savings_budget_pct > committedBudget.alloc_assets_pct ? '+' : ''}
                  {((recommendation.savings_budget_pct - committedBudget.alloc_assets_pct) * 100).toFixed(1)}%
                </span>
              </div>
            </div>
          </div>
        )}

        <div className="mt-6 pt-4 border-t border-white/10">
          <button
            onClick={onClose}
            className="w-full px-4 py-2 bg-[#D4AF37] hover:bg-[#D4AF37]/90 text-black font-semibold rounded-lg transition-colors"
          >
            Close
          </button>
        </div>
      </div>
    </div>
  )
}
