'use client'

import { useState } from 'react'
import type { Session } from '@supabase/supabase-js'
import type { Transaction } from '@/types/spendsense'
import { glassCardPrimary } from '@/lib/theme/glass'

interface TransactionDetailModalProps {
  session: Session
  transaction: Transaction
  isOpen: boolean
  onClose: () => void
  onEdit: () => void
  onDelete: () => void
}

export default function TransactionDetailModal({
  transaction,
  isOpen,
  onClose,
  onEdit,
  onDelete,
}: TransactionDetailModalProps) {
  if (!isOpen) return null

  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('en-IN', {
      style: 'currency',
      currency: 'INR',
      maximumFractionDigits: 0,
    }).format(Math.abs(amount))
  }

  const formatDate = (dateString: string) => {
    const date = new Date(dateString)
    return date.toLocaleDateString('en-US', {
      weekday: 'long',
      month: 'short',
      day: 'numeric',
      year: 'numeric',
    })
  }

  const isDebit = transaction.direction === 'debit'
  const categoryColor = getCategoryColor(transaction.category || '')

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm">
      <div className={`relative ${glassCardPrimary} p-6 max-w-md w-full mx-4 max-h-[90vh] overflow-y-auto`}>
        {/* Close Button */}
        <button
          onClick={onClose}
          className="absolute top-4 right-4 p-2 rounded-lg hover:bg-white/10 transition-colors"
        >
          <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>

        {/* Transaction Header */}
        <div className="text-center mb-6">
          <div className={`inline-flex items-center justify-center w-16 h-16 rounded-full mb-4 ${categoryColor.bg}`}>
            <span className={`text-2xl ${categoryColor.text}`}>
              {getMerchantIcon(transaction.merchant || '')}
            </span>
          </div>
          <p
            className={`text-4xl font-bold mb-2 ${
              isDebit ? 'text-red-600 dark:text-red-400' : 'text-green-600 dark:text-green-400'
            }`}
          >
            {isDebit ? '-' : '+'}
            {formatCurrency(transaction.amount)}
          </p>
          <p className="text-xl font-semibold text-foreground">
            {transaction.merchant || 'Transaction'}
          </p>
        </div>

        {/* Details */}
        <div className={`${glassCardPrimary} p-4 mb-4`}>
          <h3 className="text-lg font-bold mb-4 text-foreground">Details</h3>
          <div className="space-y-3">
            <DetailRow label="Date" value={formatDate(transaction.txn_date)} />
            {transaction.category && (
              <>
                <div className="h-px bg-white/10" />
                <DetailRow label="Category" value={transaction.category} />
              </>
            )}
            {transaction.subcategory && (
              <>
                <div className="h-px bg-white/10" />
                <DetailRow label="Subcategory" value={transaction.subcategory} />
              </>
            )}
            <div className="h-px bg-white/10" />
            <DetailRow label="Type" value={isDebit ? 'Debit' : 'Credit'} />
            {transaction.channel && (
              <>
                <div className="h-px bg-white/10" />
                <DetailRow label="Channel" value={transaction.channel.toUpperCase()} />
              </>
            )}
            {transaction.bank_code && (
              <>
                <div className="h-px bg-white/10" />
                <DetailRow label="Bank" value={transaction.bank_code} />
              </>
            )}
          </div>
        </div>

        {/* Actions */}
        <div className="flex gap-3">
          <button
            onClick={onEdit}
            className="flex-1 px-4 py-3 rounded-lg bg-white/10 border border-white/20 hover:bg-white/20 transition-colors font-medium"
          >
            Edit
          </button>
          <button
            onClick={onDelete}
            className="flex-1 px-4 py-3 rounded-lg bg-red-500/20 border border-red-500/30 hover:bg-red-500/30 transition-colors font-medium text-red-400"
          >
            Delete
          </button>
        </div>
      </div>
    </div>
  )
}

function DetailRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-center justify-between">
      <span className="text-sm font-medium text-gray-400">{label}</span>
      <span className="text-sm font-semibold text-foreground">{value}</span>
    </div>
  )
}

function getCategoryColor(category: string): { bg: string; text: string } {
  const cat = category.toLowerCase()
  if (cat.includes('food') || cat.includes('dining')) {
    return { bg: 'bg-orange-500/20', text: 'text-orange-400' }
  } else if (cat.includes('shopping')) {
    return { bg: 'bg-purple-500/20', text: 'text-purple-400' }
  } else if (cat.includes('transport') || cat.includes('travel')) {
    return { bg: 'bg-blue-500/20', text: 'text-blue-400' }
  } else if (cat.includes('entertainment')) {
    return { bg: 'bg-red-500/20', text: 'text-red-400' }
  } else if (cat.includes('income')) {
    return { bg: 'bg-green-500/20', text: 'text-green-400' }
  }
  return { bg: 'bg-[#D4AF37]/20', text: 'text-[#D4AF37]' }
}

function getMerchantIcon(merchant: string): string {
  const m = merchant.toLowerCase()
  if (m.includes('amazon')) return '🛒'
  if (m.includes('netflix') || m.includes('spotify')) return '📺'
  if (m.includes('uber') || m.includes('ola')) return '🚗'
  if (m.includes('zomato') || m.includes('swiggy')) return '🍴'
  return '💳'
}
