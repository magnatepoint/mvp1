'use client'

import { glassCardPrimary } from '@/lib/theme/glass'

interface UncategorizedAlertProps {
  amount: number
  percentage: number
  transactionCount: number
  onFixClick: () => void
}

export default function UncategorizedAlert({
  amount,
  percentage,
  transactionCount,
  onFixClick,
}: UncategorizedAlertProps) {
  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('en-IN', {
      style: 'currency',
      currency: 'INR',
      maximumFractionDigits: 0,
    }).format(amount)
  }

  if (percentage < 10) return null // Don't show if less than 10% uncategorized

  return (
    <div className={`${glassCardPrimary} p-6 border-orange-500/30 ring-2 ring-orange-500/20`}>
      <div className="flex items-start justify-between gap-4">
        <div className="flex-1">
          <div className="flex items-center gap-3 mb-2">
            <span className="text-3xl">⚠️</span>
            <div>
              <h3 className="text-lg font-bold text-orange-400">High Uncategorized Spending</h3>
              <p className="text-sm text-gray-400 mt-1">
                {percentage.toFixed(1)}% of your spending ({formatCurrency(amount)}) is uncategorized
              </p>
            </div>
          </div>
          <p className="text-sm text-gray-300 mt-3">
            You have <strong>{transactionCount} uncategorized transactions</strong>. Categorizing them will unlock
            better insights and help you understand your spending patterns.
          </p>
        </div>
        <button
          onClick={onFixClick}
          className="px-6 py-3 bg-orange-500 hover:bg-orange-600 text-white font-semibold rounded-lg transition-colors whitespace-nowrap"
        >
          Fix Now
        </button>
      </div>
    </div>
  )
}
