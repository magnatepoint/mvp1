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
    channel: transaction.channel || null,
    txn_type: null,
  })
  const [categories, setCategories] = useState<Category[]>([])
  const [subcategories, setSubcategories] = useState<Subcategory[]>([])
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (isOpen) {
      loadCategories()
    }
  }, [isOpen])

  useEffect(() => {
    if (categories.length > 0 && transaction.category) {
      const foundCat = categories.find((c) => c.category_name === transaction.category)
      if (foundCat) {
        setFormData((prev) => ({ ...prev, category_code: foundCat.category_code }))
      }
    }
  }, [categories, transaction.category])

  useEffect(() => {
    if (formData.category_code) {
      loadSubcategories(formData.category_code)
    } else {
      setSubcategories([])
      setFormData((prev) => ({ ...prev, subcategory_code: null }))
    }
  }, [formData.category_code])

  useEffect(() => {
    if (subcategories.length > 0 && transaction.subcategory) {
      const foundSub = subcategories.find((s) => s.subcategory_name === transaction.subcategory)
      if (foundSub) {
        setFormData((prev) => ({ ...prev, subcategory_code: foundSub.subcategory_code }))
      }
    }
  }, [subcategories, transaction.subcategory])

  const loadCategories = async () => {
    try {
      const cats = await fetchCategories(session)
      setCategories(cats)
      // Set initial category_code if transaction has category
      if (transaction.category) {
        const foundCat = cats.find((c) => c.category_name === transaction.category)
        if (foundCat) {
          setFormData((prev) => ({ ...prev, category_code: foundCat.category_code }))
        }
      }
    } catch (err) {
      console.error('Failed to load categories:', err)
    }
  }

  const loadSubcategories = async (categoryCode: string) => {
    try {
      const subs = await fetchSubcategories(session, categoryCode)
      setSubcategories(subs)
      // Set initial subcategory_code if transaction has subcategory
      if (transaction.subcategory) {
        const foundSub = subs.find((s) => s.subcategory_name === transaction.subcategory)
        if (foundSub) {
          setFormData((prev) => ({ ...prev, subcategory_code: foundSub.subcategory_code }))
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

    setLoading(true)
    try {
      await updateTransaction(session, transaction.txn_id, {
        ...formData,
        merchant_name: formData.merchant_name.trim(),
      })
      onSuccess()
      onClose()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to update transaction')
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
              onChange={(e) => setFormData({ ...formData, channel: e.target.value || null })}
              disabled={loading}
              className={`w-full ${glassFilter} px-4 py-3 rounded-lg text-foreground disabled:opacity-50`}
            >
              <option value="">Select channel</option>
              <option value="upi">UPI</option>
              <option value="neft">NEFT</option>
              <option value="imps">IMPS</option>
              <option value="card">Card</option>
              <option value="atm">ATM</option>
              <option value="ach">ACH</option>
              <option value="nach">NACH</option>
              <option value="other">Other</option>
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
