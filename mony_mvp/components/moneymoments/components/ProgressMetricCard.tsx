'use client'

import { glassCardPrimary } from '@/lib/theme/glass'

interface ProgressMetricCardProps {
  icon: string
  value: string
  label: string
  color: 'red' | 'blue' | 'green' | 'brown'
}

export default function ProgressMetricCard({ icon, value, label, color }: ProgressMetricCardProps) {
  const colorClasses = {
    red: 'text-red-400',
    blue: 'text-blue-400',
    green: 'text-green-400',
    brown: 'text-amber-600',
  }

  const iconMap: Record<string, string> = {
    'flame.fill': '🔥',
    'bell.fill': '🔔',
    'checkmark.circle.fill': '✓',
    'banknote.fill': '💰',
  }

  const displayIcon = iconMap[icon] || '📊'

  return (
    <div className={`${glassCardPrimary} p-4 flex-1`}>
      <div className="flex items-center gap-3">
        <span className="text-2xl">{displayIcon}</span>
        <div className="flex-1 min-w-0">
          <p className={`text-2xl font-bold ${colorClasses[color]}`}>{value}</p>
          <p className="text-sm text-gray-400 mt-1">{label}</p>
        </div>
      </div>
    </div>
  )
}
