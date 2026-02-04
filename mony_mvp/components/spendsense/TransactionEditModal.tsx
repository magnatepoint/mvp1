'use client'

import { useState, useEffect } from 'react'
import type { Session } from '@supabase/supabase-js'
import { updateTransaction } from '@/lib/api/spendsense'
import { fetchCategories, fetchSubcategories } from '@/lib/api/spendsense'
import type { Transaction, Category, Subcategory, TransactionUpdate } from '@/types/spendsense'
import { glassCardPrimary, glassFilter } from '@/lib/theme/glass'

interface TransactionEditModalProps {
  session: Session
  transaction: Transaction
  isOpen: boolean
  onClose: () => void
  onSuccess: () => void
}

export default function TransactionEditModal({
  session,
  transaction,
  isOpen,
  onClose,
  onSuccess,
}: TransactionEditModalProps) {
  const [formData, setFormData] = useState<TransactionUpdate>({
    merchant_name: transaction.merchant || null,
    category_code: null,
    subcategory_code: null,
    channel: transaction.channel ? transaction.channel.toLowerCase() : null,
    txn_type: null,
  })
  const [categories, setCategories] = useState<Category[]>([])
  const [subcategories, setSubcategories] = useState<Subcategory[]>([])
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  // Reset form data when modal opens or transaction changes
  useEffect(() => {
    if (isOpen) {
      setFormData({
        merchant_name: transaction.merchant || null,
        category_code: null,
        subcategory_code: null,
        channel: transaction.channel ? transaction.channel.toLowerCase() : null,
        txn_type: null,
      })
      setSubcategories([])
      setError(null)
      loadCategories()
    }
  }, [isOpen, transaction.txn_id])

  useEffect(() => {
    if (categories.length > 0 && transaction.category && !formData.category_code) {
      // Use case-insensitive, trimmed matching for better reliability
      const transactionCategory = transaction.category.trim()
      const foundCat = categories.find((c) => 
        c.category_name.trim().toLowerCase() === transactionCategory.toLowerCase()
      )
      if (foundCat) {
        setFormData((prev) => ({ ...prev, category_code: foundCat.category_code }))
      }
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [categories, transaction.category])

  useEffect(() => {
    if (formData.category_code) {
      loadSubcategories(formData.category_code)
    } else {
      setSubcategories([])
      setFormData((prev) => ({ ...prev, subcategory_code: null }))
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [formData.category_code])

  useEffect(() => {
    if (subcategories.length > 0 && transaction.subcategory && !formData.subcategory_code) {
      // Use case-insensitive, trimmed matching for better reliability
      const transactionSubcategory = transaction.subcategory.trim()
      const foundSub = subcategories.find((s) => 
        s.subcategory_name.trim().toLowerCase() === transactionSubcategory.toLowerCase()
      )
      if (foundSub) {
        setFormData((prev) => ({ ...prev, subcategory_code: foundSub.subcategory_code }))
      }
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [subcategories, transaction.subcategory])

  const loadCategories = async () => {
    try {
      const cats = await fetchCategories(session)
      setCategories(cats)
      // Set initial category_code if transaction has category
      // Use case-insensitive, trimmed matching for better reliability
      if (transaction.category) {
        const transactionCategory = transaction.category.trim()
        const foundCat = cats.find((c) => 
          c.category_name.trim().toLowerCase() === transactionCategory.toLowerCase()
        )
        if (foundCat) {
          setFormData((prev) => ({ ...prev, category_code: foundCat.category_code }))
        } else {
          // Log for debugging if category name doesn't match
          console.warn('Category not found in list:', transaction.category, 'Available categories:', cats.map(c => c.category_name))
        }
      }
    } catch (err) {
      console.error('Failed to load categories:', err)
      setError('Failed to load categories. Please try again.')
    }
  }

  const loadSubcategories = async (categoryCode: string) => {
    try {
      const subs = await fetchSubcategories(session, categoryCode)
      setSubcategories(subs)
      // Set initial subcategory_code if transaction has subcategory
      // Use case-insensitive, trimmed matching for better reliability
      if (transaction.subcategory) {
        const transactionSubcategory = transaction.subcategory.trim()
        const foundSub = subs.find((s) => 
          s.subcategory_name.trim().toLowerCase() === transactionSubcategory.toLowerCase()
        )
        if (foundSub) {
          setFormData((prev) => ({ ...prev, subcategory_code: foundSub.subcategory_code }))
        } else {
          // Log for debugging if subcategory name doesn't match
          console.warn('Subcategory not found in list:', transaction.subcategory, 'Available subcategories:', subs.map(s => s.subcategory_name))
        }
      }
    } catch (err) {
      console.error('Failed to load subcategories:', err)
    }
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setError(null)

    if (!formData.merchant_name?.trim()) {
      setError('Merchant name is required')
      return
    }

    // Validate session before attempting update
    if (!session?.access_token) {
      setError('Session expired. Please refresh the page and try again.')
      return
    }

    setLoading(true)
    try {
      await updateTransaction(session, transaction.txn_id, {
        ...formData,
        merchant_name: formData.merchant_name.trim(),
      })
      onSuccess()
      onClose()
    } catch (err) {
      console.error('Transaction update error:', err)
      let errorMessage = 'Failed to update transaction'
      
      if (err instanceof Error) {
        errorMessage = err.message
        // Provide more helpful messages for common errors
        if (err.message.includes('Network error')) {
          errorMessage = 'Unable to connect to server. Please check your internet connection and try again.'
        } else if (err.message.includes('Authentication')) {
          errorMessage = 'Your session has expired. Please refresh the page and try again.'
        } else if (err.message.includes('404')) {
          errorMessage = 'Transaction not found. It may have been deleted.'
        } else if (err.message.includes('403') || err.message.includes('401')) {
          errorMessage = 'You do not have permission to update this transaction.'
        }
      }
      
      setError(errorMessage)
    } finally {
      setLoading(false)
    }
  }

  if (!isOpen) return null

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm">
      <div className={`relative ${glassCardPrimary} p-6 max-w-md w-full mx-4 max-h-[90vh] overflow-y-auto`}>
        {/* Close Button */}
        <button
          onClick={onClose}
          disabled={loading}
          className="absolute top-4 right-4 p-2 rounded-lg hover:bg-white/10 transition-colors disabled:opacity-50"
        >
          <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>

        {/* Header */}
        <div className="mb-6">
          <h2 className="text-2xl font-bold mb-2">Edit Transaction</h2>
          <p className="text-sm text-gray-400">Update transaction details</p>
        </div>

        {/* Form */}
        <form onSubmit={handleSubmit} className="space-y-4">
          {/* Merchant Name */}
          <div>
            <label className="block text-sm font-medium mb-2">Merchant Name *</label>
            <input
              type="text"
              value={formData.merchant_name || ''}
              onChange={(e) => setFormData({ ...formData, merchant_name: e.target.value || null })}
              required
              disabled={loading}
              className={`w-full ${glassFilter} px-4 py-3 rounded-lg text-foreground disabled:opacity-50`}
            />
          </div>

          {/* Category */}
          <div>
            <label className="block text-sm font-medium mb-2">Category</label>
            <select
              value={formData.category_code || ''}
              onChange={(e) =>
                setFormData({ ...formData, category_code: e.target.value || null, subcategory_code: null })
              }
              disabled={loading}
              className={`w-full ${glassFilter} px-4 py-3 rounded-lg text-foreground disabled:opacity-50`}
            >
              <option value="">Select category</option>
              {categories.map((cat) => (
                <option key={cat.category_code} value={cat.category_code}>
                  {cat.category_name}
                </option>
              ))}
            </select>
          </div>

          {/* Subcategory */}
          {formData.category_code && subcategories.length > 0 && (
            <div>
              <label className="block text-sm font-medium mb-2">Subcategory</label>
              <select
                value={formData.subcategory_code || ''}
                onChange={(e) => setFormData({ ...formData, subcategory_code: e.target.value || null })}
                disabled={loading}
                className={`w-full ${glassFilter} px-4 py-3 rounded-lg text-foreground disabled:opacity-50`}
              >
                <option value="">Select subcategory</option>
                {subcategories.map((sub) => (
                  <option key={sub.subcategory_code} value={sub.subcategory_code}>
                    {sub.subcategory_name}
                  </option>
                ))}
              </select>
            </div>
          )}

          {/* Channel */}
          <div>
            <label className="block text-sm font-medium mb-2">Channel</label>
            <select
              value={formData.channel || ''}
              onChange={(e) => {
                const channelValue = e.target.value || null
                setFormData({ ...formData, channel: channelValue ? channelValue.toLowerCase() : null })
              }}
              disabled={loading}
              className={`w-full ${glassFilter} px-4 py-3 rounded-lg text-foreground disabled:opacity-50`}
            >
              <option key="channel-empty" value="">Select channel</option>
              <option key="channel-cash" value="cash">Cash</option>
              <option key="channel-upi" value="upi">UPI</option>
              <option key="channel-neft" value="neft">NEFT</option>
              <option key="channel-imps" value="imps">IMPS</option>
              <option key="channel-card" value="card">Card</option>
              <option key="channel-atm" value="atm">ATM</option>
              <option key="channel-ach" value="ach">ACH</option>
              <option key="channel-nach" value="nach">NACH</option>
              <option key="channel-other" value="other">Other</option>
            </select>
          </div>

          {/* Error Message */}
          {error && (
            <div className="p-3 rounded-lg bg-red-500/10 border border-red-500/20">
              <p className="text-sm text-red-400">{error}</p>
            </div>
          )}

          {/* Actions */}
          <div className="flex gap-3 pt-4">
            <button
              type="button"
              onClick={onClose}
              disabled={loading}
              className="flex-1 px-4 py-3 rounded-lg bg-white/5 border border-white/10 hover:bg-white/10 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={loading}
              className="flex-1 px-4 py-3 rounded-lg bg-[#D4AF37] text-black font-medium hover:bg-[#D4AF37]/90 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {loading ? 'Updating...' : 'Update Transaction'}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}
