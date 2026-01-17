'use client'

import type { InsightsResponse } from '@/types/console'
import SpendingTimeSeriesChart from '../charts/SpendingTimeSeriesChart'
import CategoryBreakdownChart from '../charts/CategoryBreakdownChart'
import TopMerchantsList from '../components/TopMerchantsList'
import ActionableInsights from '../components/ActionableInsights'

interface OverviewTabProps {
  insights: InsightsResponse
  onCategoryClick?: (categoryCode: string) => void
  onFixUncategorized?: () => void
}

export default function OverviewTab({ insights, onCategoryClick, onFixUncategorized }: OverviewTabProps) {
  // Extract income data from spending_trends if available
  const incomeData = insights.spending_trends?.map((trend) => ({
    date: trend.period,
    value: trend.income,
    label: trend.period,
  }))

  return (
    <div className="space-y-6">
      {/* Time Series Chart */}
      {insights.time_series && insights.time_series.length > 0 && (
        <SpendingTimeSeriesChart data={insights.time_series} incomeData={incomeData} />
      )}

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Category Breakdown Chart */}
        {insights.category_breakdown && insights.category_breakdown.length > 0 && (
          <CategoryBreakdownChart data={insights.category_breakdown} onCategoryClick={onCategoryClick} />
        )}

        {/* Top Merchants */}
        {insights.top_merchants && insights.top_merchants.length > 0 && (
          <TopMerchantsList merchants={insights.top_merchants} limit={8} />
        )}
      </div>

      {/* Actionable Insights */}
      {onFixUncategorized && <ActionableInsights insights={insights} onFixUncategorized={onFixUncategorized} />}

      {/* Recurring Transactions */}
      {insights.recurring_transactions && insights.recurring_transactions.length > 0 && (
        <div className="space-y-3">
          <h3 className="text-lg font-bold">Recurring Subscriptions</h3>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
            {insights.recurring_transactions.slice(0, 6).map((recurring, index) => (
              <RecurringTransactionCard key={index} transaction={recurring} />
            ))}
          </div>
        </div>
      )}
    </div>
  )
}

function RecurringTransactionCard({ transaction }: { transaction: any }) {
  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('en-IN', {
      style: 'currency',
      currency: 'INR',
      maximumFractionDigits: 0,
    }).format(amount)
  }

  return (
    <div className="bg-white/5 backdrop-blur-sm border border-white/10 rounded-xl p-4">
      <div className="flex items-center justify-between">
        <div>
          <h4 className="font-semibold">{transaction.merchant_name}</h4>
          <div className="flex items-center gap-2 mt-1 text-sm text-gray-400">
            {transaction.category_name && <span>{transaction.category_name}</span>}
            <span>•</span>
            <span className="capitalize">{transaction.frequency}</span>
          </div>
        </div>
        <div className="text-right">
          <p className="font-bold">{formatCurrency(transaction.avg_amount)}</p>
          <p className="text-xs text-gray-400">per {transaction.frequency}</p>
        </div>
      </div>
    </div>
  )
}
