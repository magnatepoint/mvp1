'use client'

import { useEffect, useState } from 'react'
import type { Session } from '@supabase/supabase-js'
import { fetchKPIs, fetchAvailableMonths, fetchTransactions, refreshKPIs } from '@/lib/api/spendsense'
import type { SpendSenseKPIs, TopCategory } from '@/types/spendsense'
import { glassCardPrimary, glassCardSecondary, glassSection, glassFilter } from '@/lib/theme/glass'

interface CategoriesTabProps {
  session: Session
}

export default function CategoriesTab({ session }: CategoriesTabProps) {
  const [kpis, setKPIs] = useState<SpendSenseKPIs | null>(null)
  const [availableMonths, setAvailableMonths] = useState<string[]>([])
  const [selectedMonth, setSelectedMonth] = useState<string | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [refreshing, setRefreshing] = useState(false)

  const loadData = async () => {
    setLoading(true)
    setError(null)
    try {
      // First check if there are any transactions at all
      const transactionsResponse = await fetchTransactions(session, { limit: 1 })
      const hasTransactions = transactionsResponse.total > 0

      if (!hasTransactions) {
        // No transactions - show empty state
        setKPIs(null)
        setAvailableMonths([])
        setLoading(false)
        return
      }

      const [kpisData, months] = await Promise.all([
        fetchKPIs(session, selectedMonth || undefined),
        fetchAvailableMonths(session),
      ])
      setKPIs(kpisData)
      setAvailableMonths(months)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load KPIs')
      console.error('Error loading KPIs:', err)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    loadData()
  }, [session, selectedMonth])

  const handleRefresh = async () => {
    setRefreshing(true)
    try {
      await refreshKPIs(session)
      // Refetch KPIs after refresh
      await loadData()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to refresh KPIs')
      console.error('Error refreshing KPIs:', err)
    } finally {
      setRefreshing(false)
    }
  }

  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('en-IN', {
      style: 'currency',
      currency: 'INR',
      maximumFractionDigits: 0,
    }).format(amount)
  }

  const calculateSavingsRate = () => {
    if (!kpis) return 0
    const income = kpis.income_amount || 0
    const expenses = (kpis.needs_amount || 0) + (kpis.wants_amount || 0)
    if (income === 0) return 0
    return ((income - expenses) / income) * 100
  }

  // Check if there's actual transaction data (not just zeros from backend)
  const hasTransactionData = () => {
    if (!kpis) return false
    
    // Backend sets month=null when there are no transactions - this is the most reliable check
    if (kpis.month === null || kpis.month === undefined) {
      return false
    }
    
    // Additional check: verify there's actual data
    const hasIncome = (kpis.income_amount || 0) > 0
    const hasNeeds = (kpis.needs_amount || 0) > 0
    const hasWants = (kpis.wants_amount || 0) > 0
    const hasAssets = (kpis.assets_amount || 0) > 0
    const hasCategories = kpis.top_categories && kpis.top_categories.length > 0
    
    return hasIncome || hasNeeds || hasWants || hasAssets || hasCategories
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
          <p className="text-lg font-bold mb-2">Unable to Load Data</p>
          <p className="text-sm">{error}</p>
        </div>
        <button
          onClick={loadData}
          className="px-6 py-2 bg-foreground text-background rounded-lg font-medium hover:opacity-90 transition-opacity"
        >
          Retry
        </button>
      </div>
    )
  }

  if (!kpis) {
    return (
      <div className="flex flex-col items-center justify-center py-20 gap-4">
        <p className="text-gray-500 dark:text-gray-400">No KPI data available</p>
        <p className="text-sm text-gray-400 dark:text-gray-500">
          Upload transaction statements to see your spending insights
        </p>
      </div>
    )
  }

  // Check if backend returned zeros (no transaction data)
  if (!hasTransactionData()) {
    return (
      <div className="flex flex-col items-center justify-center py-20 gap-4">
        <span className="text-5xl">📊</span>
        <p className="text-lg font-semibold text-gray-500 dark:text-gray-400">No Transaction Data</p>
        <p className="text-sm text-gray-400 dark:text-gray-500 text-center max-w-md">
          Upload your transaction statements to see spending insights, KPIs, and financial health metrics.
        </p>
      </div>
    )
  }

  return (
    <div className="max-w-7xl mx-auto space-y-6">
      {/* Month Filter */}
      {availableMonths.length > 0 && (
        <div className={`${glassFilter} p-4`}>
          <div className="flex items-center gap-4">
            <label className="text-sm font-medium">Month:</label>
            <select
              value={selectedMonth || ''}
              onChange={(e) => setSelectedMonth(e.target.value || null)}
              className="flex-1 px-3 py-2 rounded-lg border border-white/10 bg-white/5 dark:bg-white/5 backdrop-blur-sm text-foreground"
            >
              <option value="">Latest Available</option>
              {availableMonths.map((month) => (
                <option key={month} value={month}>
                  {new Date(month + '-01').toLocaleDateString('en-US', {
                    month: 'long',
                    year: 'numeric',
                  })}
                </option>
              ))}
            </select>
            <button
              onClick={handleRefresh}
              disabled={refreshing}
              className="px-4 py-2 bg-[#D4AF37]/20 hover:bg-[#D4AF37]/30 border border-[#D4AF37]/30 rounded-lg font-medium text-[#D4AF37] disabled:opacity-50 disabled:cursor-not-allowed transition-colors flex items-center gap-2"
              title="Refresh KPI calculations"
            >
              {refreshing ? (
                <>
                  <div className="animate-spin rounded-full h-4 w-4 border-t-2 border-b-2 border-[#D4AF37]"></div>
                  <span>Refreshing...</span>
                </>
              ) : (
                <>
                  <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
                  </svg>
                  <span>Refresh</span>
                </>
              )}
            </button>
          </div>
        </div>
      )}

      {/* Financial Health Summary */}
      <div className={`relative bg-gradient-to-r from-blue-500/60 to-purple-500/60 dark:from-blue-500/40 dark:to-purple-500/40 ${glassSection} p-6`}>
        <h2 className="text-lg font-semibold mb-4">Financial Health</h2>
        <div className="grid grid-cols-3 gap-4">
          <div>
            <p className="text-sm text-gray-600 dark:text-gray-400">Savings Rate</p>
            <p className="text-2xl font-bold">{calculateSavingsRate().toFixed(1)}%</p>
          </div>
          <div>
            <p className="text-sm text-gray-600 dark:text-gray-400">Total Income</p>
            <p className="text-2xl font-bold">{formatCurrency(kpis.income_amount || 0)}</p>
          </div>
          <div>
            <p className="text-sm text-gray-600 dark:text-gray-400">Total Expenses</p>
            <p className="text-2xl font-bold">
              {formatCurrency((kpis.needs_amount || 0) + (kpis.wants_amount || 0))}
            </p>
          </div>
        </div>
      </div>

      {/* Key Metrics */}
      <div>
        <h2 className="text-xl font-bold mb-4">Key Metrics</h2>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <KPICard
            label="Income"
            value={kpis.income_amount || 0}
            icon="💰"
            color="text-green-600 dark:text-green-400"
          />
          <KPICard
            label="Needs"
            value={kpis.needs_amount || 0}
            icon="🛡️"
            color="text-orange-600 dark:text-orange-400"
          />
          <KPICard
            label="Wants"
            value={kpis.wants_amount || 0}
            icon="🛍️"
            color="text-purple-600 dark:text-purple-400"
          />
          <KPICard
            label="Assets"
            value={kpis.assets_amount || 0}
            icon="💎"
            color="text-blue-600 dark:text-blue-400"
          />
        </div>
      </div>

      {/* Wants Gauge */}
      {kpis.wants_gauge && (
        <div className={`${glassSection} p-6`}>
          <h3 className="text-lg font-semibold mb-4">Wants Ratio</h3>
          <div className="space-y-2">
            <div className="flex justify-between text-sm">
              <span>{kpis.wants_gauge.label}</span>
              <span className="font-semibold">
                {(kpis.wants_gauge.ratio * 100).toFixed(1)}%
              </span>
            </div>
            <div className="w-full bg-gray-200 dark:bg-gray-700 rounded-full h-3">
              <div
                className={`h-3 rounded-full ${
                  kpis.wants_gauge.threshold_crossed
                    ? 'bg-red-500'
                    : 'bg-green-500 dark:bg-green-400'
                }`}
                style={{ width: `${Math.min(kpis.wants_gauge.ratio * 100, 100)}%` }}
              />
            </div>
          </div>
        </div>
      )}

      {/* Top Categories */}
      {kpis.top_categories && kpis.top_categories.length > 0 && (
        <div>
          <h2 className="text-xl font-bold mb-4">Top Categories</h2>
          <div className="space-y-3">
            {kpis.top_categories.map((category, index) => (
              <CategoryCard key={index} category={category} />
            ))}
          </div>
        </div>
      )}
    </div>
  )
}

function KPICard({
  label,
  value,
  icon,
  color,
}: {
  label: string
  value: number
  icon: string
  color: string
}) {
  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('en-IN', {
      style: 'currency',
      currency: 'INR',
      maximumFractionDigits: 0,
    }).format(amount)
  }

  return (
    <div className={`${glassCardPrimary} p-6`}>
      <div className="flex items-start justify-between mb-2">
        <span className="text-2xl">{icon}</span>
      </div>
      <p className="text-sm text-gray-600 dark:text-gray-400 mb-2">{label}</p>
      <p className={`text-2xl font-bold ${color}`}>{formatCurrency(value)}</p>
    </div>
  )
}

function CategoryCard({ category }: { category: TopCategory }) {
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
          <h3 className="font-semibold">{category.category_name}</h3>
          <p className="text-sm text-gray-600 dark:text-gray-400">
            {category.txn_count} transactions
          </p>
        </div>
        <div className="text-right">
          <p className="font-bold">{formatCurrency(category.spend_amount || 0)}</p>
          {category.delta_pct !== null && category.delta_pct !== undefined && (
            <p
              className={`text-sm ${
                category.delta_pct >= 0
                  ? 'text-red-600 dark:text-red-400'
                  : 'text-green-600 dark:text-green-400'
              }`}
            >
              {category.delta_pct >= 0 ? '+' : ''}
              {category.delta_pct.toFixed(1)}%
            </p>
          )}
        </div>
      </div>
    </div>
  )
}
