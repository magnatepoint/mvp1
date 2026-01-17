'use client'

import { glassCardPrimary } from '@/lib/theme/glass'
import type { InsightsResponse } from '@/types/console'

interface KeyMetricsCardsProps {
  insights: InsightsResponse
}

export default function KeyMetricsCards({ insights }: KeyMetricsCardsProps) {
  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('en-IN', {
      style: 'currency',
      currency: 'INR',
      maximumFractionDigits: 0,
    }).format(amount)
  }

  // Calculate metrics
  const totalSpending = insights.category_breakdown?.reduce((sum, cat) => sum + cat.amount, 0) || 0
  const uncategorized = insights.category_breakdown?.find((cat) => cat.category_code === 'uncategorized')
  const uncategorizedAmount = uncategorized?.amount || 0
  const uncategorizedPercentage = uncategorized?.percentage || 0
  const topCategory = insights.category_breakdown?.[0]
  const recurringCount = insights.recurring_transactions?.length || 0
  const recurringTotal = insights.recurring_transactions?.reduce((sum, r) => sum + r.total_amount, 0) || 0

  const metrics = [
    {
      label: 'Total Spending',
      value: formatCurrency(totalSpending),
      subtitle: `${insights.category_breakdown?.reduce((sum, cat) => sum + cat.transaction_count, 0) || 0} transactions`,
      icon: '💰',
      color: 'text-blue-400',
    },
    {
      label: 'Uncategorized',
      value: formatCurrency(uncategorizedAmount),
      subtitle: `${uncategorizedPercentage.toFixed(1)}% of spending`,
      icon: '⚠️',
      color: 'text-orange-400',
      highlight: uncategorizedPercentage > 20,
    },
    {
      label: 'Top Category',
      value: topCategory?.category_name || 'N/A',
      subtitle: formatCurrency(topCategory?.amount || 0),
      icon: '📊',
      color: 'text-green-400',
    },
    {
      label: 'Recurring',
      value: `${recurringCount} subscriptions`,
      subtitle: formatCurrency(recurringTotal) + '/month',
      icon: '🔄',
      color: 'text-purple-400',
    },
  ]

  return (
    <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
      {metrics.map((metric, index) => (
        <div
          key={index}
          className={`${glassCardPrimary} p-5 ${
            metric.highlight ? 'ring-2 ring-orange-500/50' : ''
          }`}
        >
          <div className="flex items-start justify-between mb-2">
            <div className="flex items-center gap-2">
              <span className="text-2xl">{metric.icon}</span>
              <span className={`text-sm font-medium ${metric.color}`}>{metric.label}</span>
            </div>
          </div>
          <div className="mt-2">
            <p className="text-2xl font-bold text-white">{metric.value}</p>
            <p className="text-xs text-gray-400 mt-1">{metric.subtitle}</p>
          </div>
        </div>
      ))}
    </div>
  )
}
