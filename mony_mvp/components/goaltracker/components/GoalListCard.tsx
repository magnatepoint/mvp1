'use client'

import type { GoalResponse, GoalProgressItem } from '@/types/goals'
import { glassCardPrimary } from '@/lib/theme/glass'

interface GoalListCardProps {
  goal: GoalResponse
  progress?: GoalProgressItem
}

export default function GoalListCard({ goal, progress }: GoalListCardProps) {
  const progressPct = progress?.progress_pct ?? 0
  const remainingAmount = progress?.remaining_amount ?? goal.estimated_cost - goal.current_savings
  const targetAmount = goal.estimated_cost

  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('en-IN', {
      style: 'currency',
      currency: 'INR',
      maximumFractionDigits: 0,
    }).format(amount)
  }

  const formatDate = (dateString: string | null) => {
    if (!dateString) return null
    try {
      return new Date(dateString).toLocaleDateString('en-IN', {
        year: 'numeric',
        month: 'short',
        day: 'numeric',
      })
    } catch {
      return null
    }
  }

  const statusColors = {
    active: 'bg-green-500/20 text-green-400 border-green-500/30',
    completed: 'bg-blue-500/20 text-blue-400 border-blue-500/30',
    archived: 'bg-gray-500/20 text-gray-400 border-gray-500/30',
  }

  const statusColor = statusColors[goal.status.toLowerCase() as keyof typeof statusColors] || statusColors.active

  return (
    <div className={`${glassCardPrimary} p-4 space-y-3`}>
      {/* Header */}
      <div className="flex items-start justify-between gap-2">
        <div className="flex-1 min-w-0">
          <h3 className="text-lg font-semibold text-white truncate">{goal.goal_name}</h3>
          <p className="text-sm text-gray-400 mt-1">{goal.goal_category}</p>
        </div>
        <span className={`px-2 py-1 rounded text-xs font-medium border ${statusColor}`}>
          {goal.status.charAt(0).toUpperCase() + goal.status.slice(1)}
        </span>
      </div>

      {/* Progress Bar */}
      <div className="space-y-1">
        <div className="flex items-center justify-between text-sm">
          <span className="text-gray-300">Progress</span>
          <span className="text-[#D4AF37] font-semibold">{progressPct.toFixed(1)}%</span>
        </div>
        <div className="w-full h-2 bg-white/10 rounded-full overflow-hidden">
          <div
            className="h-full bg-gradient-to-r from-[#D4AF37] to-[#8B5CF6] transition-all duration-300"
            style={{ width: `${Math.min(100, Math.max(0, progressPct))}%` }}
          />
        </div>
      </div>

      {/* Amounts */}
      <div className="flex items-center justify-between text-sm">
        <div>
          <p className="text-gray-400">Saved</p>
          <p className="text-white font-semibold">{formatCurrency(goal.current_savings)}</p>
        </div>
        <div className="text-right">
          <p className="text-gray-400">Target</p>
          <p className="text-white font-semibold">{formatCurrency(targetAmount)}</p>
        </div>
        <div className="text-right">
          <p className="text-gray-400">Remaining</p>
          <p className="text-[#D4AF37] font-semibold">{formatCurrency(remainingAmount)}</p>
        </div>
      </div>

      {/* Target Date */}
      {goal.target_date && (
        <div className="pt-2 border-t border-white/10">
          <p className="text-xs text-gray-400">
            Target Date: <span className="text-gray-300">{formatDate(goal.target_date)}</span>
          </p>
        </div>
      )}
    </div>
  )
}
