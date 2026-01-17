'use client'

interface BudgetSummaryRowProps {
  label: string
  percentage: number
  color: 'blue' | 'orange' | 'green'
}

export default function BudgetSummaryRow({ label, percentage, color }: BudgetSummaryRowProps) {
  const colorClasses = {
    blue: 'text-blue-400',
    orange: 'text-orange-400',
    green: 'text-green-400',
  }

  return (
    <div className="flex items-center justify-between">
      <span className="text-sm font-medium text-gray-300">{label}</span>
      <span className={`text-base font-bold ${colorClasses[color]}`}>
        {Math.round(percentage * 100)}%
      </span>
    </div>
  )
}
