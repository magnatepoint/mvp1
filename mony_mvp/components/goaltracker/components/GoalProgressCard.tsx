'use client'

import type { GoalProgressItem } from '@/types/goals'
import { glassCardPrimary } from '@/lib/theme/glass'

interface GoalProgressCardProps {
  progress: GoalProgressItem
}

export default function GoalProgressCard({ progress }: GoalProgressCardProps) {
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

  const progressPct = Math.min(100, Math.max(0, progress.progress_pct))

  return (
    <div className={`${glassCardPrimary} p-4 space-y-3`}>
      {/* Goal Name */}
      <h3 className="text-lg font-semibold text-white">{progress.goal_name}</h3>

      {/* Circular Progress Indicator */}
      <div className="flex items-center justify-center py-4">
        <div className="relative w-24 h-24">
          <svg className="w-24 h-24 transform -rotate-90" viewBox="0 0 100 100">
            {/* Background circle */}
            <circle
              cx="50"
              cy="50"
              r="40"
              stroke="rgba(255, 255, 255, 0.1)"
              strokeWidth="8"
              fill="none"
            />
            {/* Progress circle */}
            <circle
              cx="50"
              cy="50"
              r="40"
              stroke="url(#progressGradient)"
              strokeWidth="8"
              fill="none"
              strokeDasharray={`${2 * Math.PI * 40}`}
              strokeDashoffset={`${2 * Math.PI * 40 * (1 - progressPct / 100)}`}
              strokeLinecap="round"
              className="transition-all duration-500"
            />
            <defs>
              <linearGradient id="progressGradient" x1="0%" y1="0%" x2="100%" y2="0%">
                <stop offset="0%" stopColor="#D4AF37" />
                <stop offset="100%" stopColor="#8B5CF6" />
              </linearGradient>
            </defs>
          </svg>
          <div className="absolute inset-0 flex items-center justify-center">
            <span className="text-2xl font-bold text-white">{progressPct.toFixed(0)}%</span>
          </div>
        </div>
      </div>

      {/* Amounts */}
      <div className="space-y-2">
        <div className="flex items-center justify-between">
          <span className="text-sm text-gray-400">Current Savings</span>
          <span className="text-sm font-semibold text-white">
            {formatCurrency(progress.current_savings_close)}
          </span>
        </div>
        <div className="flex items-center justify-between">
          <span className="text-sm text-gray-400">Remaining</span>
          <span className="text-sm font-semibold text-[#D4AF37]">
            {formatCurrency(progress.remaining_amount)}
          </span>
        </div>
      </div>

      {/* Projected Completion Date */}
      {progress.projected_completion_date && (
        <div className="pt-2 border-t border-white/10">
          <p className="text-xs text-gray-400">
            Projected Completion:{' '}
            <span className="text-gray-300">
              {formatDate(progress.projected_completion_date)}
            </span>
          </p>
        </div>
      )}
    </div>
  )
}
