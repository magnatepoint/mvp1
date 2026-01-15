'use client'

import { useEffect, useState } from 'react'
import type { Session } from '@supabase/supabase-js'
import { fetchInsights } from '@/lib/api/spendsense'
import type { InsightsResponse } from '@/types/console'
import { glassCardSecondary } from '@/lib/theme/glass'

interface InsightsTabProps {
  session: Session
}

export default function InsightsTab({ session }: InsightsTabProps) {
  const [insights, setInsights] = useState<InsightsResponse | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const loadInsights = async () => {
    setLoading(true)
    setError(null)
    try {
      const data = await fetchInsights(session)
      setInsights(data)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load insights')
      console.error('Error loading insights:', err)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    loadInsights()
  }, [session])

  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('en-IN', {
      style: 'currency',
      currency: 'INR',
      maximumFractionDigits: 0,
    }).format(amount)
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center py-20">
        <div className="animate-spin rounded-full h-12 w-12 border-t-2 border-b-2 border-foreground"></div>
      </div>
    )
  }

  if (error) {
    return (
      <div className="flex flex-col items-center justify-center py-20 gap-4">
        <div className="text-red-500 text-center">
          <p className="text-lg font-bold mb-2">Unable to Load Insights</p>
          <p className="text-sm">{error}</p>
        </div>
        <button
          onClick={loadInsights}
          className="px-6 py-2 bg-foreground text-background rounded-lg font-medium hover:opacity-90 transition-opacity"
        >
          Retry
        </button>
      </div>
    )
  }

  if (!insights) {
    return (
      <div className="flex flex-col items-center justify-center py-20 gap-4">
        <span className="text-5xl">💡</span>
        <p className="text-lg font-semibold">No insights available</p>
        <p className="text-sm text-gray-500 dark:text-gray-400">Pull down to refresh</p>
      </div>
    )
  }

  return (
    <div className="max-w-7xl mx-auto space-y-6">
      {/* Category Breakdown */}
      {insights.category_breakdown && insights.category_breakdown.length > 0 && (
        <div>
          <h2 className="text-xl font-bold mb-4">Category Breakdown</h2>
          <div className="space-y-3">
            {insights.category_breakdown.map((category, index) => (
              <CategoryBreakdownCard key={index} category={category} />
            ))}
          </div>
        </div>
      )}

      {/* Recurring Transactions */}
      {insights.recurring_transactions && insights.recurring_transactions.length > 0 && (
        <div>
          <h2 className="text-xl font-bold mb-4">Recurring Transactions</h2>
          <div className="space-y-3">
            {insights.recurring_transactions.map((recurring, index) => (
              <RecurringTransactionCard key={index} transaction={recurring} />
            ))}
          </div>
        </div>
      )}

      {(!insights.category_breakdown || insights.category_breakdown.length === 0) &&
        (!insights.recurring_transactions || insights.recurring_transactions.length === 0) && (
          <div className="flex flex-col items-center justify-center py-20 gap-4">
            <span className="text-5xl">💡</span>
            <p className="text-lg font-semibold">No insights available</p>
            <p className="text-sm text-gray-500 dark:text-gray-400">
              Upload more transactions to see insights
            </p>
          </div>
        )}
    </div>
  )
}

function CategoryBreakdownCard({ category }: { category: any }) {
  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('en-IN', {
      style: 'currency',
      currency: 'INR',
      maximumFractionDigits: 0,
    }).format(amount)
  }

  return (
    <div className={`${glassCardSecondary} p-4`}>
      <div className="flex items-center justify-between mb-3">
        <h3 className="font-semibold">{category.category_name}</h3>
        <p className="font-bold">{formatCurrency(category.amount)}</p>
      </div>
      <div className="flex items-center gap-3">
        <div className="flex-1 bg-gray-200 dark:bg-gray-700 rounded-full h-2 overflow-hidden">
          <div
            className="bg-blue-500 dark:bg-blue-400 h-2 transition-all"
            style={{ width: `${category.percentage}%` }}
          />
        </div>
        <span className="text-sm text-gray-600 dark:text-gray-400 w-16 text-right">
          {category.percentage.toFixed(1)}%
        </span>
      </div>
      <p className="text-xs text-gray-500 dark:text-gray-500 mt-2">
        {category.transaction_count} transactions
      </p>
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
    <div className={`${glassCardSecondary} p-4`}>
      <div className="flex items-center justify-between">
        <div>
          <h3 className="font-semibold">{transaction.merchant_name}</h3>
          <div className="flex items-center gap-2 mt-1 text-sm text-gray-600 dark:text-gray-400">
            {transaction.category_name && <span>{transaction.category_name}</span>}
            <span>•</span>
            <span className="capitalize">{transaction.frequency}</span>
          </div>
        </div>
        <div className="text-right">
          <p className="font-bold">{formatCurrency(transaction.avg_amount)}</p>
          <p className="text-xs text-gray-500 dark:text-gray-500">avg per {transaction.frequency}</p>
        </div>
      </div>
    </div>
  )
}
