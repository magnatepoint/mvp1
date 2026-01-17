'use client'

import { useState, useMemo } from 'react'
import type { Session } from '@supabase/supabase-js'
import { fetchTransactions, fetchCategories } from '@/lib/api/spendsense'
import type { Transaction } from '@/types/spendsense'
import { glassCardSecondary } from '@/lib/theme/glass'

interface ClickableBudgetCategoryProps {
  session: Session
  label: string
  percentage: number
  color: 'blue' | 'orange' | 'green'
  plannedAmount?: number
  actualAmount?: number
  varianceAmount?: number
  txnType: 'needs' | 'wants' | 'assets'
  onViewTransactions?: (transactions: Transaction[]) => void
}

export default function ClickableBudgetCategory({
  session,
  label,
  percentage,
  color,
  plannedAmount,
  actualAmount,
  varianceAmount,
  txnType,
  onViewTransactions,
}: ClickableBudgetCategoryProps) {
  const [loading, setLoading] = useState(false)
  const [expanded, setExpanded] = useState(false)

  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('en-IN', {
      style: 'currency',
      currency: 'INR',
      maximumFractionDigits: 0,
    }).format(amount)
  }

  const colorClasses = {
    blue: {
      text: 'text-blue-400',
      bg: 'bg-blue-500/20',
      border: 'border-blue-500/30',
      hover: 'hover:bg-blue-500/30',
    },
    orange: {
      text: 'text-orange-400',
      bg: 'bg-orange-500/20',
      border: 'border-orange-500/30',
      hover: 'hover:bg-orange-500/30',
    },
    green: {
      text: 'text-green-400',
      bg: 'bg-green-500/20',
      border: 'border-green-500/30',
      hover: 'hover:bg-green-500/30',
    },
  }

  const handleClick = async () => {
    if (expanded) {
      setExpanded(false)
      return
    }

    setLoading(true)
    try {
      // Get current month for filtering
      const today = new Date()
      const firstDay = new Date(today.getFullYear(), today.getMonth(), 1)
      const lastDay = new Date(today.getFullYear(), today.getMonth() + 1, 0)

      // Fetch transactions and categories in parallel
      const [transactionsResponse, categories] = await Promise.all([
        fetchTransactions(session, {
          limit: 200, // Get more to filter client-side
          direction: 'debit',
          start_date: firstDay.toISOString().split('T')[0],
          end_date: lastDay.toISOString().split('T')[0],
        }),
        fetchCategories(session),
      ])

      // Build category_code -> txn_type mapping
      const categoryTxnTypeMap = new Map<string, string>()
      categories.forEach((cat) => {
        if (cat.category_code && cat.txn_type) {
          categoryTxnTypeMap.set(cat.category_code, cat.txn_type)
        }
      })

      // Filter transactions by txn_type
      // Map txnType prop to expected values: 'needs' | 'wants' | 'assets'
      const expectedTxnType = txnType === 'assets' ? 'assets' : txnType
      
      const filteredTransactions = transactionsResponse.transactions.filter((txn) => {
        if (!txn.category) {
          return false // Skip uncategorized transactions
        }
        const txnTypeForCategory = categoryTxnTypeMap.get(txn.category) || 'wants'
        return txnTypeForCategory === expectedTxnType
      })

      if (onViewTransactions) {
        onViewTransactions(filteredTransactions)
      } else {
        setExpanded(true)
      }
    } catch (err) {
      console.error('Failed to load transactions:', err)
    } finally {
      setLoading(false)
    }
  }

  const variancePct = plannedAmount && plannedAmount > 0
    ? ((varianceAmount || 0) / plannedAmount) * 100
    : 0
  const isOverBudget = varianceAmount && varianceAmount < 0

  return (
    <div
      className={`${glassCardSecondary} p-4 cursor-pointer transition-all border ${
        expanded ? colorClasses[color].border : 'border-transparent'
      } ${colorClasses[color].hover}`}
      onClick={handleClick}
    >
      <div className="flex items-center justify-between">
        <div className="flex-1">
          <div className="flex items-center gap-3 mb-2">
            <span className={`text-base font-semibold ${colorClasses[color].text}`}>{label}</span>
            <span className={`text-lg font-bold ${colorClasses[color].text}`}>
              {Math.round(percentage * 100)}%
            </span>
          </div>

          {/* Amounts */}
          {plannedAmount !== undefined && (
            <div className="space-y-1 text-sm">
              <div className="flex items-center justify-between">
                <span className="text-gray-400">Planned:</span>
                <span className="text-white font-medium">{formatCurrency(plannedAmount)}</span>
              </div>
              {actualAmount !== undefined && (
                <div className="flex items-center justify-between">
                  <span className="text-gray-400">Actual:</span>
                  <span className="text-white font-medium">{formatCurrency(actualAmount)}</span>
                </div>
              )}
              {varianceAmount !== undefined && (
                <div className="flex items-center justify-between">
                  <span className="text-gray-400">Variance:</span>
                  <span className={`font-semibold ${isOverBudget ? 'text-red-400' : 'text-green-400'}`}>
                    {isOverBudget ? '+' : '-'}
                    {formatCurrency(Math.abs(varianceAmount))} ({Math.abs(variancePct).toFixed(1)}%)
                  </span>
                </div>
              )}
            </div>
          )}
        </div>

        <div className="flex items-center gap-2">
          {loading ? (
            <div className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin" />
          ) : (
            <svg
              className={`w-5 h-5 transition-transform ${expanded ? 'rotate-180' : ''}`}
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
            </svg>
          )}
        </div>
      </div>

      {expanded && (
        <div className="mt-3 pt-3 border-t border-white/10">
          <p className="text-xs text-gray-400 mb-2">Click to view transactions in this category</p>
          <button
            onClick={(e) => {
              e.stopPropagation()
              handleClick()
            }}
            className="text-xs text-[#D4AF37] hover:underline"
          >
            View all {label.toLowerCase()} transactions →
          </button>
        </div>
      )}
    </div>
  )
}
