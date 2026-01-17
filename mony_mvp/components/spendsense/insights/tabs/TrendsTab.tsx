'use client'

import type { InsightsResponse } from '@/types/console'
import SpendingTrendsChart from '../charts/SpendingTrendsChart'
import IncomeVsExpensesChart from '../charts/IncomeVsExpensesChart'
import { glassCardSecondary } from '@/lib/theme/glass'

interface TrendsTabProps {
  insights: InsightsResponse
}

export default function TrendsTab({ insights }: TrendsTabProps) {
  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('en-IN', {
      style: 'currency',
      currency: 'INR',
      maximumFractionDigits: 0,
    }).format(amount)
  }

  if (!insights.spending_trends || insights.spending_trends.length === 0) {
    return (
      <div className="flex items-center justify-center py-20">
        <p className="text-gray-400">No trend data available</p>
      </div>
    )
  }

  // Calculate summary stats
  const latest = insights.spending_trends[insights.spending_trends.length - 1]
  const previous = insights.spending_trends[insights.spending_trends.length - 2]
  const needsChange = previous ? ((latest.needs - previous.needs) / previous.needs) * 100 : 0
  const wantsChange = previous ? ((latest.wants - previous.wants) / previous.wants) * 100 : 0
  const assetsChange = previous ? ((latest.assets - previous.assets) / previous.assets) * 100 : 0

  return (
    <div className="space-y-6">
      {/* Summary Cards */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div className={`${glassCardSecondary} p-4`}>
          <div className="flex items-center justify-between mb-2">
            <span className="text-sm text-gray-400">Needs</span>
            <span className={`text-xs font-semibold ${needsChange >= 0 ? 'text-red-400' : 'text-green-400'}`}>
              {needsChange >= 0 ? '↑' : '↓'} {Math.abs(needsChange).toFixed(1)}%
            </span>
          </div>
          <p className="text-2xl font-bold">{formatCurrency(latest.needs)}</p>
          <p className="text-xs text-gray-400 mt-1">Essential expenses</p>
        </div>
        <div className={`${glassCardSecondary} p-4`}>
          <div className="flex items-center justify-between mb-2">
            <span className="text-sm text-gray-400">Wants</span>
            <span className={`text-xs font-semibold ${wantsChange >= 0 ? 'text-red-400' : 'text-green-400'}`}>
              {wantsChange >= 0 ? '↑' : '↓'} {Math.abs(wantsChange).toFixed(1)}%
            </span>
          </div>
          <p className="text-2xl font-bold">{formatCurrency(latest.wants)}</p>
          <p className="text-xs text-gray-400 mt-1">Discretionary spending</p>
        </div>
        <div className={`${glassCardSecondary} p-4`}>
          <div className="flex items-center justify-between mb-2">
            <span className="text-sm text-gray-400">Assets</span>
            <span className={`text-xs font-semibold ${assetsChange >= 0 ? 'text-green-400' : 'text-red-400'}`}>
              {assetsChange >= 0 ? '↑' : '↓'} {Math.abs(assetsChange).toFixed(1)}%
            </span>
          </div>
          <p className="text-2xl font-bold">{formatCurrency(latest.assets)}</p>
          <p className="text-xs text-gray-400 mt-1">Investments & savings</p>
        </div>
      </div>

      {/* Charts */}
      <SpendingTrendsChart data={insights.spending_trends} />
      <IncomeVsExpensesChart data={insights.spending_trends} />
    </div>
  )
}
