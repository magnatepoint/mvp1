'use client'

import { glassCardSecondary } from '@/lib/theme/glass'

interface BudgetInfoCardProps {
  title: string
  value: string | number
  subtitle?: string
  icon?: string
  color?: 'blue' | 'orange' | 'green' | 'purple'
  onClick?: () => void
}

export default function BudgetInfoCard({
  title,
  value,
  subtitle,
  icon,
  color = 'blue',
  onClick,
}: BudgetInfoCardProps) {
  const colorClasses = {
    blue: 'bg-blue-500/20 border-blue-500/30 text-blue-400',
    orange: 'bg-orange-500/20 border-orange-500/30 text-orange-400',
    green: 'bg-green-500/20 border-green-500/30 text-green-400',
    purple: 'bg-purple-500/20 border-purple-500/30 text-purple-400',
  }

  return (
    <div
      className={`${glassCardSecondary} p-4 border ${colorClasses[color]} ${
        onClick ? 'cursor-pointer hover:bg-white/10 transition-colors' : ''
      }`}
      onClick={onClick}
    >
      <div className="flex items-start justify-between">
        <div className="flex-1">
          <div className="flex items-center gap-2 mb-1">
            {icon && <span className="text-lg">{icon}</span>}
            <span className="text-sm font-medium text-gray-300">{title}</span>
          </div>
          <p className="text-xl font-bold text-white">{value}</p>
          {subtitle && <p className="text-xs text-gray-400 mt-1">{subtitle}</p>}
        </div>
        {onClick && (
          <svg
            className="w-5 h-5 text-gray-400"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
          </svg>
        )}
      </div>
    </div>
  )
}
