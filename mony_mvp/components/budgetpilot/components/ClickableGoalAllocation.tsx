'use client'

import { useState } from 'react'
import type { Session } from '@supabase/supabase-js'
import { fetchGoalProgress } from '@/lib/api/goals'
import type { GoalProgressItem } from '@/types/console'
import { glassCardSecondary } from '@/lib/theme/glass'

interface ClickableGoalAllocationProps {
  session: Session
  goalId: string
  goalName: string
  plannedAmount: number
  onViewGoal?: (goal: GoalProgressItem) => void
}

export default function ClickableGoalAllocation({
  session,
  goalId,
  goalName,
  plannedAmount,
  onViewGoal,
}: ClickableGoalAllocationProps) {
  const [loading, setLoading] = useState(false)
  const [expanded, setExpanded] = useState(false)
  const [goalProgress, setGoalProgress] = useState<GoalProgressItem | null>(null)

  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('en-IN', {
      style: 'currency',
      currency: 'INR',
      maximumFractionDigits: 0,
    }).format(amount)
  }

  const handleClick = async () => {
    if (expanded) {
      setExpanded(false)
      return
    }

    setLoading(true)
    try {
      const goals = await fetchGoalProgress(session)
      const goal = goals.find((g) => g.goal_id === goalId)
      
      if (goal) {
        setGoalProgress(goal)
        if (onViewGoal) {
          onViewGoal(goal)
        }
        setExpanded(true)
      } else {
        // Goal might not be in progress list, create a basic progress item
        const basicGoal: GoalProgressItem = {
          goal_id: goalId,
          goal_name: goalName,
          progress_pct: 0,
          current_savings_close: 0,
          remaining_amount: plannedAmount,
          milestones: [],
        }
        setGoalProgress(basicGoal)
        setExpanded(true)
      }
    } catch (err) {
      console.error('Failed to load goal progress:', err)
      // Still expand to show basic info
      setExpanded(true)
    } finally {
      setLoading(false)
    }
  }

  return (
    <div
      className={`${glassCardSecondary} p-4 cursor-pointer transition-all hover:bg-white/10 border ${
        expanded ? 'border-[#D4AF37]/30' : 'border-transparent'
      }`}
      onClick={handleClick}
    >
      <div className="flex items-center justify-between">
        <div className="flex-1">
          <div className="flex items-center gap-2 mb-2">
            <span className="text-base font-semibold text-white">{goalName}</span>
          </div>
          <div className="flex items-center justify-between">
            <span className="text-sm text-gray-400">Planned allocation:</span>
            <span className="text-lg font-bold text-[#D4AF37]">{formatCurrency(plannedAmount)}</span>
          </div>

          {expanded && goalProgress && (
            <div className="mt-3 pt-3 border-t border-white/10 space-y-2">
              <div className="flex items-center justify-between text-sm">
                <span className="text-gray-400">Progress:</span>
                <span className="text-white font-semibold">{goalProgress.progress_pct.toFixed(1)}%</span>
              </div>
              <div className="flex items-center justify-between text-sm">
                <span className="text-gray-400">Saved:</span>
                <span className="text-white font-semibold">{formatCurrency(goalProgress.current_savings_close)}</span>
              </div>
              <div className="flex items-center justify-between text-sm">
                <span className="text-gray-400">Remaining:</span>
                <span className="text-white font-semibold">{formatCurrency(goalProgress.remaining_amount)}</span>
              </div>
              <div className="w-full bg-gray-700/50 rounded-full h-2 mt-2 overflow-hidden">
                <div
                  className="bg-[#D4AF37] h-2 transition-all"
                  style={{ width: `${Math.min(100, goalProgress.progress_pct)}%` }}
                />
              </div>
            </div>
          )}
        </div>

        <div className="flex items-center gap-2">
          {loading ? (
            <div className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin" />
          ) : (
            <svg
              className={`w-5 h-5 transition-transform ${expanded ? 'rotate-180' : ''}`}
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
            </svg>
          )}
        </div>
      </div>
    </div>
  )
}
