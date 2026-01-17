'use client'

import { glassCardSecondary } from '@/lib/theme/glass'

export type InsightType = 'spending_alert' | 'trend' | 'recommendation' | 'achievement'

interface InsightCardProps {
  type: InsightType
  title: string
  message: string
  actionLabel?: string
  onAction?: () => void
  icon?: string
}

export default function InsightCard({ type, title, message, actionLabel, onAction, icon }: InsightCardProps) {
  const getIcon = () => {
    if (icon) return icon
    switch (type) {
      case 'spending_alert':
        return '⚠️'
      case 'trend':
        return '📈'
      case 'recommendation':
        return '💡'
      case 'achievement':
        return '🎉'
      default:
        return '💡'
    }
  }

  const getColor = () => {
    switch (type) {
      case 'spending_alert':
        return 'border-orange-500/30 bg-orange-500/10'
      case 'trend':
        return 'border-blue-500/30 bg-blue-500/10'
      case 'recommendation':
        return 'border-purple-500/30 bg-purple-500/10'
      case 'achievement':
        return 'border-green-500/30 bg-green-500/10'
      default:
        return ''
    }
  }

  return (
    <div className={`${glassCardSecondary} p-4 border ${getColor()}`}>
      <div className="flex items-start gap-3">
        <span className="text-2xl">{getIcon()}</span>
        <div className="flex-1">
          <h4 className="font-semibold mb-1">{title}</h4>
          <p className="text-sm text-gray-300">{message}</p>
          {actionLabel && onAction && (
            <button
              onClick={onAction}
              className="mt-3 px-4 py-2 bg-[#D4AF37] hover:bg-[#D4AF37]/90 text-black text-sm font-semibold rounded-lg transition-colors"
            >
              {actionLabel}
            </button>
          )}
        </div>
      </div>
    </div>
  )
}
