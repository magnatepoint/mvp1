'use client'

import { useState, useEffect } from 'react'
import type { Session } from '@supabase/supabase-js'
import { createTransaction, fetchCategories, fetchSubcategories, fetchChannels } from '@/lib/api/spendsense'
import type { Category, Subcategory, TransactionCreate } from '@/types/spendsense'
import { glassCardPrimary, glassFilter } from '@/lib/theme/glass'

interface ManualTransactionModalProps {
  session: Session
  isOpen: boolean
  onClose: () => void
  onSuccess: () => void
}

export default function ManualTransactionModal({
  session,
  isOpen,
  onClose,
  onSuccess,
}: ManualTransactionModalProps) {
  const [formData, setFormData] = useState<TransactionCreate>({
    txn_date: new Date().toISOString().split('T')[0],
    merchant_name: '',
    description: null,
    amount: 0,
    direction: 'debit',
    category_code: null,
    subcategory_code: null,
    channel: null,
    account_ref: null,
  })
  const [categories, setCategories] = useState<Category[]>([])
  const [subcategories, setSubcategories] = useState<Subcategory[]>([])
  const [channels, setChannels] = useState<string[]>([])
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  // Fallback if channels API fails or returns empty
  const channelOptions = channels.length > 0 ? channels : ['cash', 'upi', 'neft', 'imps', 'card', 'atm', 'ach', 'nach', 'other']

  useEffect(() => {
    if (isOpen) {
      loadCategories()
      loadChannels()
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isOpen])

  useEffect(() => {
    if (formData.category_code) {
      loadSubcategories(formData.category_code)
    } else {
      setSubcategories([])
      setFormData((prev) => ({ ...prev, subcategory_code: null }))
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [formData.category_code])

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

  const loadChannels = async () => {
    try {
      const list = await fetchChannels(session)
      setChannels(Array.isArray(list) ? list : [])
    } catch (err) {
      console.error('Failed to load channels:', err)
      setChannels([])
    }
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setError(null)

    // Validation
    if (!formData.merchant_name.trim()) {
      setError('Merchant name is required')
      return
    }
    if (formData.amount <= 0) {
      setError('Amount must be greater than 0')
      return
    }
    if (!formData.category_code) {
      setError('Category is required')
      return
    }
    // Subcategory is required only if the category has subcategories available
    if (formData.category_code && subcategories.length > 0 && !formData.subcategory_code) {
      setError('Subcategory is required for this category')
      return
    }
    const selectedDate = new Date(formData.txn_date)
    const today = new Date()
    today.setHours(23, 59, 59, 999)
    if (selectedDate > today) {
      setError('Date cannot be in the future')
      return
    }

    setLoading(true)
    try {
      await createTransaction(session, {
        ...formData,
        merchant_name: formData.merchant_name.trim(),
        description: formData.description?.trim() || null,
      })
      onSuccess()
      onClose()
      // Reset form
      setFormData({
        txn_date: new Date().toISOString().split('T')[0],
        merchant_name: '',
        description: null,
        amount: 0,
        direction: 'debit',
        category_code: null,
        subcategory_code: null,
        channel: null,
        account_ref: null,
      })
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Failed to create transaction'
      // Make network errors more helpful
      const isNetworkError = err instanceof Error && (err as any).isNetworkError
      setError(
        isNetworkError && message.includes('Unable to reach')
          ? `${message} If you're running locally, ensure the backend is running and NEXT_PUBLIC_API_URL points to it (e.g. http://localhost:8000).`
          : message
      )
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
          <h2 className="text-2xl font-bold mb-2">Add Transaction</h2>
          <p className="text-sm text-gray-400">Enter transaction details manually</p>
        </div>

        {/* Form */}
        <form onSubmit={handleSubmit} className="space-y-4">
          {/* Date */}
          <div>
            <label className="block text-sm font-medium mb-2">Date *</label>
            <input
              type="date"
              value={formData.txn_date}
              onChange={(e) => setFormData({ ...formData, txn_date: e.target.value })}
              required
              max={new Date().toISOString().split('T')[0]}
              disabled={loading}
              className={`w-full ${glassFilter} px-4 py-3 rounded-lg text-foreground disabled:opacity-50`}
            />
          </div>

          {/* Merchant Name */}
          <div>
            <label className="block text-sm font-medium mb-2">Merchant Name *</label>
            <input
              type="text"
              value={formData.merchant_name}
              onChange={(e) => setFormData({ ...formData, merchant_name: e.target.value })}
              required
              disabled={loading}
              placeholder="e.g., Amazon, Grocery Store"
              className={`w-full ${glassFilter} px-4 py-3 rounded-lg text-foreground placeholder-gray-500 disabled:opacity-50`}
            />
          </div>

          {/* Amount */}
          <div>
            <label className="block text-sm font-medium mb-2">Amount *</label>
            <input
              type="number"
              step="0.01"
              min="0.01"
              value={formData.amount || ''}
              onChange={(e) => setFormData({ ...formData, amount: parseFloat(e.target.value) || 0 })}
              required
              disabled={loading}
              placeholder="0.00"
              className={`w-full ${glassFilter} px-4 py-3 rounded-lg text-foreground placeholder-gray-500 disabled:opacity-50`}
            />
          </div>

          {/* Direction */}
          <div>
            <label className="block text-sm font-medium mb-2">Type *</label>
            <div className="flex gap-3">
              <button
                type="button"
                onClick={() => setFormData({ ...formData, direction: 'debit' })}
                disabled={loading}
                className={`flex-1 px-4 py-3 rounded-lg font-medium transition-colors disabled:opacity-50 ${
                  formData.direction === 'debit'
                    ? 'bg-red-500/20 border border-red-500/30 text-red-400'
                    : 'bg-white/5 border border-white/10 hover:bg-white/10'
                }`}
              >
                Debit (Expense)
              </button>
              <button
                type="button"
                onClick={() => setFormData({ ...formData, direction: 'credit' })}
                disabled={loading}
                className={`flex-1 px-4 py-3 rounded-lg font-medium transition-colors disabled:opacity-50 ${
                  formData.direction === 'credit'
                    ? 'bg-green-500/20 border border-green-500/30 text-green-400'
                    : 'bg-white/5 border border-white/10 hover:bg-white/10'
                }`}
              >
                Credit (Income)
              </button>
            </div>
          </div>

          {/* Category */}
          <div>
            <label className="block text-sm font-medium mb-2">Category *</label>
            <select
              value={formData.category_code || ''}
              onChange={(e) =>
                setFormData({ ...formData, category_code: e.target.value || null, subcategory_code: null })
              }
              required
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
          {formData.category_code && (
            <div>
              <label className="block text-sm font-medium mb-2">
                Subcategory {subcategories.length > 0 ? '*' : ''}
              </label>
              {subcategories.length > 0 ? (
                <select
                  value={formData.subcategory_code || ''}
                  onChange={(e) => setFormData({ ...formData, subcategory_code: e.target.value || null })}
                  required={subcategories.length > 0}
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
              ) : (
                <div className="p-3 rounded-lg bg-yellow-500/10 border border-yellow-500/20">
                  <p className="text-sm text-yellow-400">
                    No subcategories available for this category. Subcategory is optional.
                  </p>
                </div>
              )}
            </div>
          )}

          {/* Channel (fetched from backend: distinct from DB + standard list) */}
          <div>
            <label className="block text-sm font-medium mb-2">Channel (optional)</label>
            <select
              value={formData.channel || ''}
              onChange={(e) => setFormData({ ...formData, channel: e.target.value || null })}
              disabled={loading}
              className={`w-full ${glassFilter} px-4 py-3 rounded-lg text-foreground disabled:opacity-50`}
            >
              <option value="">Select channel</option>
              {channelOptions.map((code) => (
                <option key={code} value={code}>
                  {code.charAt(0).toUpperCase() + code.slice(1)}
                </option>
              ))}
            </select>
          </div>

          {/* Description */}
          <div>
            <label className="block text-sm font-medium mb-2">Description (optional)</label>
            <textarea
              value={formData.description || ''}
              onChange={(e) => setFormData({ ...formData, description: e.target.value || null })}
              disabled={loading}
              rows={3}
              placeholder="Additional notes..."
              className={`w-full ${glassFilter} px-4 py-3 rounded-lg text-foreground placeholder-gray-500 disabled:opacity-50`}
            />
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
              {loading ? 'Creating...' : 'Create Transaction'}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}
