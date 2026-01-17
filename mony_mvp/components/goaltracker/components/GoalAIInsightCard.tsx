'use client'

import type { AIInsight } from '@/types/goals'
import { glassCardPrimary } from '@/lib/theme/glass'

interface GoalAIInsightCardProps {
  insight: AIInsight
}

export default function GoalAIInsightCard({ insight }: GoalAIInsightCardProps) {
  const typeColors = {
    goalProgress: 'bg-purple-500/20 text-purple-400 border-purple-500/30',
    savingsOpportunity: 'bg-green-500/20 text-green-400 border-green-500/30',
    budgetTip: 'bg-blue-500/20 text-blue-400 border-blue-500/30',
  }

  const priorityColors = {
    high: 'bg-red-500/20 text-red-400',
    medium: 'bg-yellow-500/20 text-yellow-400',
    low: 'bg-gray-500/20 text-gray-400',
  }

  const typeColor = typeColors[insight.type] || typeColors.budgetTip
  const priorityColor = priorityColors[insight.priority] || priorityColors.low

  const formatDate = (dateString: string | null | undefined) => {
    if (!dateString) return null
    try {
      const date = new Date(dateString)
      const now = new Date()
      const diffMs = now.getTime() - date.getTime()
      const diffHours = Math.floor(diffMs / (1000 * 60 * 60))
      const diffDays = Math.floor(diffHours / 24)

      if (diffHours < 1) return 'Just now'
      if (diffHours < 24) return `${diffHours}h ago`
      if (diffDays < 7) return `${diffDays}d ago`
      return date.toLocaleDateString('en-IN', { month: 'short', day: 'numeric' })
    } catch {
      return null
    }
  }

  return (
    <div className={`${glassCardPrimary} p-4 space-y-3`}>
      {/* Header */}
      <div className="flex items-start justify-between gap-2">
        <div className="flex-1 min-w-0">
          <h3 className="text-base font-semibold text-white">{insight.title}</h3>
        </div>
        <div className="flex items-center gap-2">
          <span className={`px-2 py-1 rounded text-xs font-medium border ${typeColor}`}>
            {insight.type}
          </span>
          <span className={`px-2 py-1 rounded text-xs font-medium ${priorityColor}`}>
            {insight.priority}
          </span>
        </div>
      </div>

      {/* Message */}
      <p className="text-sm text-gray-300 leading-relaxed">{insight.message}</p>

      {/* Footer */}
      <div className="flex items-center justify-between pt-2 border-t border-white/10">
        {insight.category && (
          <span className="text-xs text-gray-400">{insight.category}</span>
        )}
        {insight.createdAt && (
          <span className="text-xs text-gray-500 ml-auto">
            {formatDate(insight.createdAt)}
          </span>
        )}
      </div>
    </div>
  )
}
