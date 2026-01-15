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
      const insights = await fetchInsights(session)
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

  if (loading) {
    return (
      <div className="flex items-center justify-center py-20">
        <div className="animate-spin rounded-full h-12 w-12 border-t-2 border-b-2 border-[#D4AF37]"></div>
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
