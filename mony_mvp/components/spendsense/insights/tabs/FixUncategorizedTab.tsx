'use client'

import { useState } from 'react'
import type { Session } from '@supabase/supabase-js'
import { updateTransaction } from '@/lib/api/spendsense'
import UncategorizedTransactions from '../uncategorized/UncategorizedTransactions'
import { glassCardPrimary, glassCardSecondary } from '@/lib/theme/glass'
import { fetchCategories, fetchSubcategories } from '@/lib/api/spendsense'
import type { Category, Subcategory } from '@/types/spendsense'

interface FixUncategorizedTabProps {
  session: Session
  uncategorizedCount: number
  uncategorizedAmount: number
  uncategorizedPercentage: number
}

export default function FixUncategorizedTab({
  session,
  uncategorizedCount,
  uncategorizedAmount,
  uncategorizedPercentage,
}: FixUncategorizedTabProps) {
  const [categories, setCategories] = useState<Category[]>([])
  const [subcategories, setSubcategories] = useState<Subcategory[]>([])
  const [selectedCategory, setSelectedCategory] = useState<string | null>(null)

  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('en-IN', {
      style: 'currency',
      currency: 'INR',
      maximumFractionDigits: 0,
    }).format(amount)
  }

  const handleCategorize = async (txnId: string, categoryCode: string, subcategoryCode?: string) => {
    try {
      await updateTransaction(session, txnId, {
        category_code: categoryCode,
        subcategory_code: subcategoryCode || null,
      })
      // Refresh the list
      window.location.reload()
    } catch (err) {
      console.error('Failed to categorize transaction:', err)
      alert('Failed to categorize transaction. Please try again.')
    }
  }

  return (
    <div className="space-y-6">
      {/* Summary Card */}
      <div className={`${glassCardPrimary} p-6`}>
        <div className="flex items-center justify-between">
          <div>
            <h3 className="text-xl font-bold mb-2">Categorization Status</h3>
            <p className="text-gray-400">
              {uncategorizedCount} transactions ({uncategorizedPercentage.toFixed(1)}%) worth{' '}
              {formatCurrency(uncategorizedAmount)} need categorization
            </p>
          </div>
          <div className="text-right">
            <div className="text-3xl font-bold text-orange-400">{uncategorizedPercentage.toFixed(1)}%</div>
            <div className="text-sm text-gray-400">Uncategorized</div>
          </div>
        </div>
        <div className="mt-4 w-full bg-gray-700/50 rounded-full h-3 overflow-hidden">
          <div
            className="bg-orange-500 h-3 transition-all"
            style={{ width: `${uncategorizedPercentage}%` }}
          />
        </div>
      </div>

      {/* Quick Tips */}
      <div className={`${glassCardSecondary} p-6`}>
        <h3 className="text-lg font-bold mb-3">💡 Quick Tips</h3>
        <ul className="space-y-2 text-sm text-gray-300">
          <li>• Select multiple transactions and categorize them in bulk</li>
          <li>• Look for merchant patterns - similar merchants often belong to the same category</li>
          <li>• Use the search to find specific merchants quickly</li>
          <li>• Categorizing transactions improves spending insights and budget tracking</li>
        </ul>
      </div>

      {/* Transactions List */}
      <UncategorizedTransactions session={session} onCategorize={handleCategorize} />
    </div>
  )
}
