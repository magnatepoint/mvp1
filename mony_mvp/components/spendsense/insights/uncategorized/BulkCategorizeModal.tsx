'use client'

import { useState, useEffect } from 'react'
import type { Session } from '@supabase/supabase-js'
import { updateTransaction } from '@/lib/api/spendsense'
import { fetchCategories, fetchSubcategories } from '@/lib/api/spendsense'
import type { Category, Subcategory } from '@/types/spendsense'
import { glassCardPrimary, glassFilter } from '@/lib/theme/glass'

interface BulkCategorizeModalProps {
  session: Session
  transactionIds: string[]
  isOpen: boolean
  onClose: () => void
  onSuccess: () => void
}

export default function BulkCategorizeModal({
  session,
  transactionIds,
  isOpen,
  onClose,
  onSuccess,
}: BulkCategorizeModalProps) {
  const [categories, setCategories] = useState<Category[]>([])
  const [subcategories, setSubcategories] = useState<Subcategory[]>([])
  const [selectedCategory, setSelectedCategory] = useState<string | null>(null)
  const [selectedSubcategory, setSelectedSubcategory] = useState<string | null>(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (isOpen) {
      loadCategories()
    }
  }, [isOpen, session])

  useEffect(() => {
    if (selectedCategory) {
      loadSubcategories(selectedCategory)
    } else {
      setSubcategories([])
      setSelectedSubcategory(null)
    }
  }, [selectedCategory, session])

  const loadCategories = async () => {
    try {
      const cats = await fetchCategories(session)
      setCategories(cats)
    } catch (err) {
      console.error('Failed to load categories:', err)
    }
  }

  const loadSubcategories = async (categoryCode: string) => {
    try {
      const subs = await fetchSubcategories(session, categoryCode)
      setSubcategories(subs)
    } catch (err) {
      console.error('Failed to load subcategories:', err)
    }
  }

  const handleCategorize = async () => {
    if (!selectedCategory || transactionIds.length === 0) {
      setError('Please select a category')
      return
    }

    setLoading(true)
    setError(null)

    try {
      // Categorize all selected transactions
      await Promise.all(
        transactionIds.map((txnId) =>
          updateTransaction(session, txnId, {
            category_code: selectedCategory,
            subcategory_code: selectedSubcategory || null,
          })
        )
      )

      onSuccess()
      onClose()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to categorize transactions')
      console.error('Bulk categorization error:', err)
    } finally {
      setLoading(false)
    }
  }

  if (!isOpen) return null

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm">
      <div className={`${glassCardPrimary} p-6 max-w-md w-full mx-4`}>
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-xl font-bold">Bulk Categorize</h2>
          <button
            onClick={onClose}
            className="p-2 rounded-lg hover:bg-white/10 transition-colors"
            disabled={loading}
          >
            <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        <p className="text-sm text-gray-400 mb-4">
          Categorize {transactionIds.length} transaction{transactionIds.length !== 1 ? 's' : ''}
        </p>

        {/* Category Selection */}
        <div className="mb-4">
          <label className="block text-sm font-medium mb-2">Category *</label>
          <select
            value={selectedCategory || ''}
            onChange={(e) => setSelectedCategory(e.target.value || null)}
            className={`w-full ${glassFilter} px-4 py-3 rounded-lg text-foreground`}
            disabled={loading}
          >
            <option value="">Select a category</option>
            {categories.map((cat) => (
              <option key={cat.category_code} value={cat.category_code}>
                {cat.category_name}
              </option>
            ))}
          </select>
        </div>

        {/* Subcategory Selection */}
        {selectedCategory && subcategories.length > 0 && (
          <div className="mb-4">
            <label className="block text-sm font-medium mb-2">Subcategory (Optional)</label>
            <select
              value={selectedSubcategory || ''}
              onChange={(e) => setSelectedSubcategory(e.target.value || null)}
              className={`w-full ${glassFilter} px-4 py-3 rounded-lg text-foreground`}
              disabled={loading}
            >
              <option value="">None</option>
              {subcategories.map((sub) => (
                <option key={sub.subcategory_code} value={sub.subcategory_code}>
                  {sub.subcategory_name}
                </option>
              ))}
            </select>
          </div>
        )}

        {/* Error Message */}
        {error && (
          <div className="mb-4 p-3 rounded-lg bg-red-500/10 border border-red-500/20">
            <p className="text-sm text-red-400">{error}</p>
          </div>
        )}

        {/* Actions */}
        <div className="flex gap-3">
          <button
            onClick={onClose}
            disabled={loading}
            className="flex-1 px-4 py-3 bg-white/10 hover:bg-white/20 rounded-lg font-medium transition-colors disabled:opacity-50"
          >
            Cancel
          </button>
          <button
            onClick={handleCategorize}
            disabled={loading || !selectedCategory}
            className="flex-1 px-4 py-3 bg-[#D4AF37] hover:bg-[#D4AF37]/90 text-black font-semibold rounded-lg transition-colors disabled:opacity-50"
          >
            {loading ? 'Categorizing...' : 'Categorize All'}
          </button>
        </div>
      </div>
    </div>
  )
}
