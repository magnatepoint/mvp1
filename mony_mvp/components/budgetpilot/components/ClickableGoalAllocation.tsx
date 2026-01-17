'use client'

import { useState } from 'react'
import type { Session } from '@supabase/supabase-js'
import { fetchGoalProgress, getGoal } from '@/lib/api/goals'
import type { GoalProgressItem } from '@/types/console'
import type { GoalResponse } from '@/types/goals'
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
  const [goalDetails, setGoalDetails] = useState<GoalResponse | null>(null)

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
      // Fetch both progress and full goal details in parallel
      const [goals, goalDetail] = await Promise.all([
        fetchGoalProgress(session).catch(() => []),
        getGoal(session, goalId).catch(() => null),
      ])
      
      // Set goal details first so it's available even if progress fetch fails
      if (goalDetail) {
        setGoalDetails(goalDetail)
      }

      const goal = goals.find((g) => g.goal_id === goalId)
      
      if (goal) {
        setGoalProgress(goal)
        if (onViewGoal) {
          onViewGoal(goal)
        }
      } else if (goalDetail) {
        // Create progress from goal details
        const progress: GoalProgressItem = {
          goal_id: goalId,
          goal_name: goalDetail.goal_name,
          progress_pct: goalDetail.estimated_cost > 0
            ? (goalDetail.current_savings / goalDetail.estimated_cost) * 100
            : 0,
          current_savings_close: goalDetail.current_savings,
          remaining_amount: Math.max(goalDetail.estimated_cost - goalDetail.current_savings, 0),
          projected_completion_date: goalDetail.target_date,
          milestones: [],
        }
        setGoalProgress(progress)
      } else {
        // Fallback: create basic progress item
        const basicGoal: GoalProgressItem = {
          goal_id: goalId,
          goal_name: goalName,
          progress_pct: 0,
          current_savings_close: 0,
          remaining_amount: plannedAmount,
          milestones: [],
        }
        setGoalProgress(basicGoal)
      }

      if (goalDetail) {
        setGoalDetails(goalDetail)
      }

      setExpanded(true)
    } catch (err) {
      console.error('Failed to load goal data:', err)
      setExpanded(true)
    } finally {
      setLoading(false)
    }
  }

  // Calculate plan to achieve goal
  const calculatePlan = () => {
    if (!goalProgress && !goalDetails) return null

    const totalGoal = goalDetails?.estimated_cost || (goalProgress ? goalProgress.current_savings_close + goalProgress.remaining_amount : 0)
    const achieved = goalProgress?.current_savings_close || goalDetails?.current_savings || 0
    const remaining = goalProgress?.remaining_amount || (totalGoal - achieved)
    const targetDate = goalDetails?.target_date || goalProgress?.projected_completion_date

    if (!targetDate || remaining <= 0) return null

    const target = new Date(targetDate)
    const today = new Date()
    const monthsRemaining = Math.max(
      1,
      Math.ceil((target.getTime() - today.getTime()) / (1000 * 60 * 60 * 24 * 30))
    )

    const monthlyNeeded = remaining / monthsRemaining
    const currentMonthly = plannedAmount

    return {
      totalGoal,
      achieved,
      remaining,
      targetDate: target,
      monthsRemaining,
      monthlyNeeded,
      currentMonthly,
      isOnTrack: currentMonthly >= monthlyNeeded,
      shortfall: Math.max(0, monthlyNeeded - currentMonthly),
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
          
          {/* Show total goal amount prominently */}
          {goalDetails ? (
            <div className="flex items-center justify-between mb-2">
              <span className="text-sm font-medium text-gray-300">Total Goal:</span>
              <span className="text-2xl font-bold text-white">{formatCurrency(goalDetails.estimated_cost)}</span>
            </div>
          ) : goalProgress ? (
            <div className="flex items-center justify-between mb-2">
              <span className="text-sm font-medium text-gray-300">Total Goal:</span>
              <span className="text-2xl font-bold text-white">
                {formatCurrency(goalProgress.current_savings_close + goalProgress.remaining_amount)}
              </span>
            </div>
          ) : null}
          
          <div className="flex items-center justify-between">
            <span className="text-sm text-gray-400">Monthly allocation:</span>
            <span className="text-base font-semibold text-[#D4AF37]">{formatCurrency(plannedAmount)}</span>
          </div>

          {expanded && (goalProgress || goalDetails) && (
            <div className="mt-3 pt-3 border-t border-white/10 space-y-3">
              {/* Progress */}
              {goalProgress && (
                <>
                  <div className="flex items-center justify-between text-sm">
                    <span className="text-gray-400">Progress:</span>
                    <span className="text-white font-semibold">{goalProgress.progress_pct.toFixed(1)}%</span>
                  </div>
                  <div className="flex items-center justify-between text-sm">
                    <span className="text-gray-400">Achieved:</span>
                    <span className="text-green-400 font-semibold">
                      {formatCurrency(goalProgress.current_savings_close)}
                    </span>
                  </div>
                  <div className="flex items-center justify-between text-sm">
                    <span className="text-gray-400">Remaining:</span>
                    <span className="text-white font-semibold">{formatCurrency(goalProgress.remaining_amount)}</span>
                  </div>
                </>
              )}

              {/* Target Date */}
              {(goalDetails?.target_date || goalProgress?.projected_completion_date) && (
                <div className="flex items-center justify-between text-sm">
                  <span className="text-gray-400">Target Date:</span>
                  <span className="text-white font-semibold">
                    {new Date(goalDetails?.target_date || goalProgress?.projected_completion_date || '').toLocaleDateString('en-IN', {
                      year: 'numeric',
                      month: 'long',
                      day: 'numeric',
                    })}
                  </span>
                </div>
              )}

              {/* Progress Bar */}
              {goalProgress && (
                <div className="w-full bg-gray-700/50 rounded-full h-2 mt-2 overflow-hidden">
                  <div
                    className="bg-[#D4AF37] h-2 transition-all"
                    style={{ width: `${Math.min(100, goalProgress.progress_pct)}%` }}
                  />
                </div>
              )}

              {/* Plan to Achieve */}
              {(() => {
                const plan = calculatePlan()
                if (!plan) return null

                return (
                  <div className="mt-4 pt-3 border-t border-white/10 bg-white/5 p-3 rounded-lg">
                    <h5 className="text-sm font-semibold text-white mb-2">Plan to Achieve Goal</h5>
                    <div className="space-y-2 text-xs">
                      <div className="flex justify-between">
                        <span className="text-gray-400">Months remaining:</span>
                        <span className="text-white font-medium">{plan.monthsRemaining} months</span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-gray-400">Monthly needed:</span>
                        <span className={`font-semibold ${plan.isOnTrack ? 'text-green-400' : 'text-red-400'}`}>
                          {formatCurrency(plan.monthlyNeeded)}
                        </span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-gray-400">Current allocation:</span>
                        <span className="text-white font-medium">{formatCurrency(plan.currentMonthly)}</span>
                      </div>
                      {!plan.isOnTrack && (
                        <div className="mt-2 pt-2 border-t border-white/10">
                          <div className="flex justify-between">
                            <span className="text-orange-400">Shortfall:</span>
                            <span className="text-orange-400 font-semibold">
                              {formatCurrency(plan.shortfall)}/month
                            </span>
                          </div>
                          <p className="text-gray-400 mt-1 text-[10px]">
                            Increase monthly allocation by {formatCurrency(plan.shortfall)} to reach goal on time
                          </p>
                        </div>
                      )}
                      {plan.isOnTrack && (
                        <div className="mt-2 pt-2 border-t border-white/10">
                          <p className="text-green-400 text-[10px] font-medium">
                            ✓ On track! Current allocation is sufficient to reach goal on time
                          </p>
                        </div>
                      )}
                    </div>
                  </div>
                )
              })()}
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
