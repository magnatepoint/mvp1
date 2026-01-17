'use client'

import { useState } from 'react'
import type { Session } from '@supabase/supabase-js'
import type { CommittedBudget, BudgetVariance } from '@/types/budget'
import { glassCardPrimary } from '@/lib/theme/glass'
import BudgetAllocationBar from './BudgetAllocationBar'
import ClickableBudgetCategory from './ClickableBudgetCategory'
import ClickableGoalAllocation from './ClickableGoalAllocation'
import BudgetVarianceChart from './BudgetVarianceChart'
import TransactionsModal from './TransactionsModal'
import type { Transaction } from '@/types/spendsense'

interface EnhancedCommittedBudgetCardProps {
  session: Session
  committedBudget: CommittedBudget
  variance?: BudgetVariance | null
  onViewGoal?: (goalId: string) => void
}

export default function EnhancedCommittedBudgetCard({
  session,
  committedBudget,
  variance,
  onViewGoal,
}: EnhancedCommittedBudgetCardProps) {
  const [selectedCategory, setSelectedCategory] = useState<string | null>(null)
  const [categoryTransactions, setCategoryTransactions] = useState<Transaction[]>([])
  const [showTransactionsModal, setShowTransactionsModal] = useState(false)

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

  // Calculate amounts from variance if available
  const needsAmount = variance ? variance.planned_needs_amt : undefined
  const wantsAmount = variance ? variance.planned_wants_amt : undefined
  const savingsAmount = variance ? variance.planned_assets_amt : undefined

  const needsActual = variance ? variance.needs_amt : undefined
  const wantsActual = variance ? variance.wants_amt : undefined
  const savingsActual = variance ? variance.assets_amt : undefined

  const needsVariance = variance ? variance.variance_needs_amt : undefined
  const wantsVariance = variance ? variance.variance_wants_amt : undefined
  const savingsVariance = variance ? variance.variance_assets_amt : undefined

  return (
    <>
      <div className={`${glassCardPrimary} p-6 space-y-6`}>
        {/* Header */}
        <div className="flex items-center justify-between">
          <div>
            <h3 className="text-xl font-bold text-white">Your Committed Budget</h3>
            <p className="text-sm text-gray-400 mt-1">
              Committed on {formatDate(committedBudget.committed_at)}
            </p>
          </div>
          <span className="text-2xl font-bold text-green-400">✓</span>
        </div>

        {/* Budget Categories - Now Clickable */}
        <div className="space-y-3">
          <ClickableBudgetCategory
            session={session}
            label="Needs"
            percentage={committedBudget.alloc_needs_pct}
            color="blue"
            plannedAmount={needsAmount}
            actualAmount={needsActual}
            varianceAmount={needsVariance}
            txnType="needs"
            onViewTransactions={(txns) => {
              setCategoryTransactions(txns)
              setSelectedCategory('Needs')
              setShowTransactionsModal(true)
            }}
          />
          <ClickableBudgetCategory
            session={session}
            label="Wants"
            percentage={committedBudget.alloc_wants_pct}
            color="orange"
            plannedAmount={wantsAmount}
            actualAmount={wantsActual}
            varianceAmount={wantsVariance}
            txnType="wants"
            onViewTransactions={(txns) => {
              setCategoryTransactions(txns)
              setSelectedCategory('Wants')
              setShowTransactionsModal(true)
            }}
          />
          <ClickableBudgetCategory
            session={session}
            label="Savings"
            percentage={committedBudget.alloc_assets_pct}
            color="green"
            plannedAmount={savingsAmount}
            actualAmount={savingsActual}
            varianceAmount={savingsVariance}
            txnType="assets"
            onViewTransactions={(txns) => {
              setCategoryTransactions(txns)
              setSelectedCategory('Savings')
              setShowTransactionsModal(true)
            }}
          />
        </div>

        {/* Allocation Bar */}
        <BudgetAllocationBar
          needsPct={committedBudget.alloc_needs_pct}
          wantsPct={committedBudget.alloc_wants_pct}
          savingsPct={committedBudget.alloc_assets_pct}
        />

        {/* Budget Variance Chart */}
        {variance && (
          <div className="pt-4 border-t border-white/10">
            <BudgetVarianceChart variance={variance} />
          </div>
        )}

        {/* Goal Allocations - Now Clickable */}
        {committedBudget.goal_allocations && committedBudget.goal_allocations.length > 0 && (
          <div className="pt-4 border-t border-white/10 space-y-3">
            <div className="flex items-center justify-between">
              <h4 className="text-base font-semibold text-white">Goal Allocations</h4>
              <span className="text-xs text-gray-400">
                {committedBudget.goal_allocations.length} goal{committedBudget.goal_allocations.length !== 1 ? 's' : ''}
              </span>
            </div>
            <div className="space-y-2">
              {committedBudget.goal_allocations.map((allocation) => (
                <ClickableGoalAllocation
                  key={allocation.ubcga_id}
                  session={session}
                  goalId={allocation.goal_id}
                  goalName={allocation.goal_name || allocation.goal_id.substring(0, 8) + '...'}
                  plannedAmount={allocation.planned_amount}
                  onViewGoal={(goal) => {
                    if (onViewGoal) {
                      onViewGoal(goal.goal_id)
                    }
                  }}
                />
              ))}
            </div>
          </div>
        )}
      </div>

      <TransactionsModal
        transactions={categoryTransactions}
        categoryName={selectedCategory || 'Category'}
        isOpen={showTransactionsModal}
        onClose={() => setShowTransactionsModal(false)}
      />
    </>
  )
}
