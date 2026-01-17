'use client'

import type { AIInsight } from '@/types/moneymoments'
import { glassCardPrimary } from '@/lib/theme/glass'

interface AIInsightCardProps {
  insight: AIInsight
}

export default function AIInsightCard({ insight }: AIInsightCardProps) {
  const getTypeColor = () => {
    switch (insight.type) {
      case 'progress':
        return 'bg-green-500/20 text-green-400'
      case 'suggestion':
        return 'bg-blue-500/20 text-blue-400'
      case 'milestone':
        return 'bg-purple-500/20 text-purple-400'
      default:
        return 'bg-gray-500/20 text-gray-400'
    }
  }

  const formatRelativeTime = (date: Date) => {
    const now = new Date()
    const diffMs = now.getTime() - date.getTime()
    const diffMins = Math.floor(diffMs / 60000)
    const diffHours = Math.floor(diffMs / 3600000)
    const diffDays = Math.floor(diffMs / 86400000)

    if (diffMins < 1) {
      return 'Just now'
    } else if (diffMins < 60) {
      return `${diffMins}m ago`
    } else if (diffHours < 24) {
      return `${diffHours}h ago`
    } else if (diffDays < 7) {
      return `${diffDays}d ago`
    } else {
      return date.toLocaleDateString('en-IN', { month: 'short', day: 'numeric' })
    }
  }

  return (
    <div className={`${glassCardPrimary} p-5 space-y-4`}>
      {/* Header with type badge and timestamp */}
      <div className="flex items-center justify-between">
        <span
          className={`px-3 py-1 rounded-full text-xs font-semibold uppercase ${getTypeColor()}`}
        >
          {insight.type}
        </span>
        <span className="text-xs text-gray-500">{formatRelativeTime(insight.timestamp)}</span>
      </div>

      {/* Icon and Message */}
      <div className="flex items-start gap-3">
        <span className="text-2xl flex-shrink-0">{insight.icon}</span>
        <p className="text-sm text-gray-300 leading-relaxed flex-1">{insight.message}</p>
      </div>
    </div>
  )
}
