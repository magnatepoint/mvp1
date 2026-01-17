'use client'

import type { MoneyMoment } from '@/types/moneymoments'
import { glassCardPrimary } from '@/lib/theme/glass'

interface MoneyMomentCardProps {
  moment: MoneyMoment
}

export default function MoneyMomentCard({ moment }: MoneyMomentCardProps) {
  const getIcon = () => {
    if (moment.habit_id.includes('burn_rate') || moment.habit_id.includes('spend_to_income')) {
      return '📈'
    } else if (moment.habit_id.includes('micro') || moment.habit_id.includes('cash')) {
      return 'ℹ️'
    } else {
      return '⚠️'
    }
  }

  const getConfidenceColor = (confidence: number) => {
    if (confidence >= 0.7) {
      return 'bg-green-500'
    } else if (confidence >= 0.5) {
      return 'bg-yellow-500'
    } else {
      return 'bg-orange-500'
    }
  }

  const formatValue = () => {
    if (moment.habit_id.includes('ratio') || moment.habit_id.includes('share')) {
      return `${Math.round(moment.value * 100)}%`
    } else if (moment.habit_id.includes('count')) {
      return `${Math.round(moment.value)}`
    } else {
      // Currency format
      return new Intl.NumberFormat('en-IN', {
        style: 'currency',
        currency: 'INR',
        maximumFractionDigits: 0,
      }).format(moment.value)
    }
  }

  const confidencePercent = Math.round(moment.confidence * 100)

  return (
    <div className={`${glassCardPrimary} p-5 space-y-4`}>
      {/* Header with icon and confidence badge */}
      <div className="flex items-start justify-between">
        <span className="text-3xl">{getIcon()}</span>
        <span
          className={`px-3 py-1 rounded-full text-xs font-semibold text-white ${getConfidenceColor(moment.confidence)}`}
        >
          {confidencePercent}%
        </span>
      </div>

      {/* Label */}
      <h3 className="text-lg font-bold text-white">{moment.label}</h3>

      {/* Insight text */}
      <p className="text-sm text-gray-300 line-clamp-3 leading-relaxed">{moment.insight_text}</p>

      {/* Value and habit ID */}
      <div className="flex items-center justify-between pt-2 border-t border-white/10">
        <span className="text-xl font-semibold text-[#D4AF37]">{formatValue()}</span>
        <span className="text-xs text-gray-500 uppercase">
          {moment.habit_id.replace(/_/g, ' ')}
        </span>
      </div>
    </div>
  )
}
