'use client'

import type { MoneyMoment } from '@/types/moneymoments'
import { glassCardPrimary } from '@/lib/theme/glass'

interface HabitCardProps {
  moment: MoneyMoment
}

export default function HabitCard({ moment }: HabitCardProps) {
  // Transform MoneyMoment into a habit-like display
  const habitName = moment.label
  const habitDescription = moment.insight_text
  const progress = Math.min(1.0, moment.confidence) // Use confidence as progress

  return (
    <div className={`${glassCardPrimary} p-5 space-y-4`}>
      {/* Header */}
      <div className="flex items-start justify-between">
        <div className="flex-1">
          <h3 className="text-lg font-bold text-white">{habitName}</h3>
          <p className="text-sm text-gray-400 mt-1">{moment.habit_id.replace(/_/g, ' ')}</p>
        </div>
        <span className="text-2xl">🔄</span>
      </div>

      {/* Description */}
      <p className="text-sm text-gray-300 leading-relaxed">{habitDescription}</p>

      {/* Progress Bar */}
      <div className="space-y-2">
        <div className="flex items-center justify-between text-xs">
          <span className="text-gray-400">Progress</span>
          <span className="text-[#D4AF37] font-semibold">{Math.round(progress * 100)}%</span>
        </div>
        <div className="w-full h-2 rounded-full bg-white/10 overflow-hidden">
          <div
            className="h-full bg-[#D4AF37] transition-all"
            style={{ width: `${progress * 100}%` }}
          />
        </div>
      </div>

      {/* Value */}
      <div className="pt-2 border-t border-white/10">
        <span className="text-sm font-semibold text-[#D4AF37]">
          Value: {moment.value.toFixed(2)}
        </span>
      </div>
    </div>
  )
}
