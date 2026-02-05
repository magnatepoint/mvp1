'use client'

import { useEffect, useState } from 'react'
import type { Session } from '@supabase/supabase-js'
import { fetchInsights, transformCategorySpending } from '@/lib/api/console'
import type { CategorySpending } from '@/types/console'
import { glassCardSecondary } from '@/lib/theme/glass'

interface SpendingTabProps {
  session: Session
}

export default function SpendingTab({ session }: SpendingTabProps) {
  const [monthlySpending, setMonthlySpending] = useState(0)
  const [spendingByCategory, setSpendingByCategory] = useState<CategorySpending[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const loadSpending = async () => {
    setLoading(true)
    setError(null)
    try {
      // Use current month so "This Month's Spending" matches KPI period
      const now = new Date()
      const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1)
      const endOfMonth = new Date(now.getFullYear(), now.getMonth() + 1, 0)
      const startDate = startOfMonth.toISOString().slice(0, 10) // YYYY-MM-DD
      const endDate = endOfMonth.toISOString().slice(0, 10)
      const insights = await fetchInsights(session, startDate, endDate)
      if (insights.category_breakdown && insights.category_breakdown.length > 0) {
        const total = insights.category_breakdown.reduce((sum, cat) => sum + cat.amount, 0)
        setMonthlySpending(total)
        setSpendingByCategory(transformCategorySpending(insights.category_breakdown))
      } else {
        setMonthlySpending(0)
        setSpendingByCategory([])
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load spending')
      console.error('Error loading spending:', err)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    loadSpending()
  }, [session])

  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('en-IN', {
      style: 'currency',
      currency: 'INR',
      maximumFractionDigits: 0,
    }).format(amount)
  }

  if (loading && spendingByCategory.length === 0 && !error) {
    return (
      <div className="max-w-7xl mx-auto space-y-6">
        <h2 className="text-xl font-bold text-white mb-4">Spending</h2>
        <div className={`${glassCardSecondary} p-6 animate-pulse`}>
          <div className="h-5 bg-white/10 rounded w-1/4 mb-4" />
          <div className="h-10 bg-white/10 rounded w-1/3" />
        </div>
        <div className="space-y-3">
          {[1, 2, 3, 4].map((i) => (
            <div key={i} className={`${glassCardSecondary} p-4 animate-pulse`}>
              <div className="flex justify-between">
                <div className="h-4 bg-white/10 rounded w-1/4" />
                <div className="h-4 bg-white/10 rounded w-1/6" />
              </div>
              <div className="h-2 bg-white/10 rounded mt-2 w-full" />
            </div>
          ))}
        </div>
      </div>
    )
  }

  if (error) {
    return (
      <div className="flex flex-col items-center justify-center py-20 gap-4">
        <div className="text-red-400 text-center">
          <p className="text-lg font-bold mb-2">Unable to Load Spending</p>
          <p className="text-sm">{error}</p>
        </div>
        <button
          onClick={loadSpending}
          className="px-6 py-2 bg-[#D4AF37] text-black rounded-lg font-medium hover:bg-[#D4AF37]/90 transition-colors"
        >
          Retry
        </button>
      </div>
    )
  }

  return (
    <div className="max-w-7xl mx-auto space-y-6">
      {/* This Month's Spending */}
      <div className="mb-6">
        <p className="text-sm text-gray-400 mb-2">This Month's Spending</p>
        <p className="text-4xl font-bold text-red-400">{formatCurrency(monthlySpending)}</p>
      </div>

      {/* Spending by Category */}
      {spendingByCategory.length > 0 ? (
        <div>
          <h2 className="text-xl font-bold text-white mb-4">Spending by Category</h2>
          <div className="space-y-4">
            {spendingByCategory.map((category) => (
              <CategorySpendingCard
                key={category.id}
                category={category}
                totalSpending={monthlySpending}
              />
            ))}
          </div>
        </div>
      ) : (
        <div className="flex flex-col items-center justify-center py-20 gap-4">
          <span className="text-5xl">💰</span>
          <p className="text-lg font-semibold text-white">No Spending Data</p>
          <p className="text-sm text-gray-400">Upload statements to see your spending breakdown</p>
        </div>
      )}
    </div>
  )
}

function CategorySpendingCard({
  category,
  totalSpending,
}: {
  category: CategorySpending
  totalSpending: number
}) {
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
        <h3 className="text-base font-semibold text-white">{category.category}</h3>
        <p className="text-base font-bold text-white">{formatCurrency(category.amount)}</p>
      </div>
      <div className="flex items-center gap-3">
        <div className="flex-1 bg-gray-700/50 rounded-full h-2 overflow-hidden">
          <div
            className="bg-[#D4AF37] h-full transition-all"
            style={{ width: `${category.percentage}%` }}
          />
        </div>
        <span className="text-xs text-gray-400 w-12 text-right">
          {category.percentage.toFixed(1)}%
        </span>
      </div>
      <p className="text-xs text-gray-500 mt-2">{category.transaction_count} transactions</p>
    </div>
  )
}
